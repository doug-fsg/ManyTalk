module Api
  module V1
    module Accounts
      module Contacts
        class PipelinePositionsController < Api::V1::Accounts::BaseController
          include Events::Types
          
          before_action :set_pipeline, except: [:reorder]
          before_action :ensure_contact, only: [:update, :destroy]

          # Atualizar ou criar posição do contato no pipeline
          # PATCH /api/v1/accounts/:account_id/contacts/:contact_id/pipeline_positions/:pipeline_id
          def update
            # Verificar se o pipeline existe (set_pipeline já valida)
            return if performed?
            
            # Verificar se o contato existe (ensure_contact já valida)
            return if performed?

            begin
              @position = ContactPipelinePosition.find_or_initialize_by(
                contact_id: params[:contact_id],
                pipeline_id: params[:pipeline_id]
              )

              new_position = params[:position].to_i
              new_stage_id = params[:stage_id]

              # Validar que stage_id existe no pipeline
              # attribute_values pode ser array simples de strings ou array de objetos {key: ..., value: ...}
              attribute_values = Array(@pipeline.attribute_values)
              
              # Verificar se stage_id existe diretamente no array ou como 'key'/'value' em objetos
              stage_exists = attribute_values.any? do |value|
                if value.is_a?(Hash)
                  # Verificar tanto 'key' quanto 'value' para compatibilidade
                  value['key'] == new_stage_id || value[:key] == new_stage_id || 
                  value['value'] == new_stage_id || value[:value] == new_stage_id
                else
                  value == new_stage_id
                end
              end
              
              unless stage_exists
                available_stages = attribute_values.map do |value|
                  if value.is_a?(Hash)
                    value['key'] || value[:key] || value['value'] || value[:value]
                  else
                    value
                  end
                end.join(', ')
                
                render json: { error: "Stage '#{new_stage_id}' not found in pipeline. Available stages: #{available_stages}" }, 
                       status: :unprocessable_entity
                return
              end

              # Se mudou de stage ou posição, reordenar
              if @position.persisted? && (@position.stage_id != new_stage_id || @position.position != new_position)
                reorder_old_positions if @position.stage_id != new_stage_id && @position.position.present?
              end

              # Preparar atributos para atualização
              update_attrs = {
                stage_id: new_stage_id,
                position: new_position,
                entered_at: params[:entered_at] || (@position.entered_at || Time.current)
              }

              # Adicionar deal_value se fornecido
              if params.key?(:deal_value)
                update_attrs[:deal_value] = params[:deal_value].present? ? params[:deal_value].to_d : nil
              end

              # Adicionar metadata se fornecido
              if params.key?(:metadata)
                update_attrs[:metadata] = params[:metadata] || {}
              end

              @position.assign_attributes(update_attrs)

              if @position.save
                # Reordenar outras posições na nova stage se necessário
                reorder_new_positions(new_stage_id, new_position) if new_position.present?

                # Disparar evento para sincronização em tempo real
                # Recarregar contato com pipeline_positions para garantir dados atualizados
                @contact.reload
                Rails.configuration.dispatcher.dispatch(
                  CONTACT_UPDATED,
                  Time.zone.now,
                  contact: @contact
                )

                render json: {
                  id: @position.id,
                  contact_id: @position.contact_id,
                  pipeline_id: @position.pipeline_id,
                  stage_id: @position.stage_id,
                  position: @position.position,
                  entered_at: @position.entered_at&.iso8601,
                  deal_value: @position.deal_value,
                  metadata: @position.metadata || {}
                }, status: :ok
              else
                Rails.logger.error "Failed to save pipeline position: #{@position.errors.full_messages.join(', ')}"
                render json: { error: @position.errors.full_messages }, status: :unprocessable_entity
              end
            rescue => e
              Rails.logger.error "Error updating pipeline position: #{e.class.name} - #{e.message}"
              Rails.logger.error e.backtrace.join("\n")
              render json: { error: e.message }, status: :internal_server_error
            end
          end

          # Remover contato do pipeline
          # DELETE /api/v1/accounts/:account_id/contacts/:contact_id/pipeline_positions/:pipeline_id
          def destroy
            return if performed?
            
            begin
              position = ContactPipelinePosition.find_by(
                contact_id: params[:contact_id],
                pipeline_id: params[:pipeline_id]
              )
              
              if position
                contact = position.contact
                position.destroy
                
                # Disparar evento para sincronização em tempo real
                contact.reload
                Rails.configuration.dispatcher.dispatch(
                  CONTACT_UPDATED,
                  Time.zone.now,
                  contact: contact
                )
                
                render json: { success: true }, status: :ok
              else
                render json: { error: 'Pipeline position not found' }, status: :not_found
              end
            rescue => e
              Rails.logger.error "Error deleting pipeline position: #{e.class.name} - #{e.message}"
              render json: { error: e.message }, status: :internal_server_error
            end
          end

          # Reordenar múltiplas posições de uma vez
          # POST /api/v1/accounts/:account_id/contacts/pipeline_positions/reorder
          def reorder
            positions_data = params[:positions] || []
            
            ActiveRecord::Base.transaction do
              positions_data.each do |pos_data|
                position = ContactPipelinePosition.find_by(
                  contact_id: pos_data[:contact_id],
                  pipeline_id: params[:pipeline_id]
                )
                
                if position
                  position.update(
                    stage_id: pos_data[:stage_id],
                    position: pos_data[:position],
                    entered_at: pos_data[:entered_at] || position.entered_at || Time.current
                  )
                end
              end
            end

            render json: { success: true }, status: :ok
          rescue => e
            render json: { error: e.message }, status: :unprocessable_entity
          end

          private

          def ensure_contact
            @contact = Current.account.contacts.find_by(id: params[:contact_id])
            unless @contact
              render json: { error: 'Contact not found' }, status: :not_found
              return
            end
          end

          def set_pipeline
            @pipeline = Current.account.custom_attribute_definitions.find_by(
              id: params[:pipeline_id],
              is_kanban: true
            )
            
            unless @pipeline
              render json: { error: 'Pipeline not found or not a kanban pipeline' }, 
                     status: :not_found
              return
            end
          end

          def reorder_old_positions
            # Reordenar posições na stage antiga (remover gap)
            # Só reordenar se position não for nil
            return unless @position.position.present?
            
            ContactPipelinePosition
              .where(pipeline_id: params[:pipeline_id], stage_id: @position.stage_id)
              .where('position > ?', @position.position)
              .update_all('position = position - 1')
          end

          def reorder_new_positions(stage_id, new_position)
            # Reordenar outras posições na nova stage (abrir espaço)
            ContactPipelinePosition
              .where(pipeline_id: params[:pipeline_id], stage_id: stage_id)
              .where.not(id: @position.id)
              .where('position >= ?', new_position)
              .update_all('position = position + 1')
          end
        end
      end
    end
  end
end

