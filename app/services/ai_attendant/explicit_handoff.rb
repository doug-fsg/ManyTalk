# frozen_string_literal: true

module AiAttendant
  class ExplicitHandoff
    REQUEST = /
      \b(
        falar\ com\ (um\ |uma\ )?(humano|atendente|pessoa|gente)
        | quero\ (um\ |uma\ )?(humano|atendente|pessoa)
        | (me\ )?(passa|passe|transfere|transfira|transferir)\ (para\ )?(um\ |uma\ )?(humano|atendente|pessoa)
        | atendimento\ humano
        | chama(r)?\ (um\ |uma\ )?(humano|atendente|pessoa)
      )\b
    /ix

    NEGATED = /\bn[aã]o\s+(quero\s+|preciso\s+)?(falar|chamar|passar|transferir)\b/i

    def self.match?(text)
      value = text.to_s
      return false if value.blank?
      return false if NEGATED.match?(value)

      value.match?(REQUEST)
    end

    def self.summary
      'Cliente pediu para falar com um atendente.'
    end
  end
end
