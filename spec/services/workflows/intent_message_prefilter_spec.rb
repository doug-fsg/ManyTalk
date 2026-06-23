# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::IntentMessagePrefilter do
  subject(:filter) { described_class.new(content, seen_normalized: seen) }

  let(:seen) { [] }

  describe '#skip?' do
    context 'with empty content' do
      let(:content) { '' }

      it { is_expected.to be_skip }
    end

    context 'with whitespace-only content' do
      let(:content) { '   ' }

      it { is_expected.to be_skip }
      it { expect(filter.skip_reason).to eq(:empty) }
    end

    context 'with emoji-only content' do
      let(:content) { '👍' }

      it { is_expected.to be_skip }
      it { expect(filter.skip_reason).to eq(:emoji_only) }
    end

    context 'with multiple emojis' do
      let(:content) { '🔥🔥🔥' }

      it { is_expected.to be_skip }
      it { expect(filter.skip_reason).to eq(:emoji_only) }
    end

    context 'with punctuation-only content (???)' do
      let(:content) { '???' }

      it { is_expected.to be_skip }
      it { expect(filter.skip_reason).to eq(:punctuation_only) }
    end

    context 'with punctuation-only content (!!!)' do
      let(:content) { '!!!' }

      it { is_expected.to be_skip }
      it { expect(filter.skip_reason).to eq(:punctuation_only) }
    end

    context 'with punctuation-only content (...)' do
      let(:content) { '...' }

      it { is_expected.to be_skip }
      it { expect(filter.skip_reason).to eq(:punctuation_only) }
    end

    context 'when content was already seen' do
      let(:content) { 'oi' }
      let(:seen) { ['oi'] }

      it { is_expected.to be_skip }
      it { expect(filter.skip_reason).to eq(:identical_repeat) }
    end

    context 'when content normalizes to same as seen' do
      let(:content) { '  OI  ' }
      let(:seen) { ['oi'] }

      it { is_expected.to be_skip }
    end

    context 'with a valid short message (first occurrence)' do
      let(:content) { 'oi' }

      it { is_expected.not_to be_skip }
    end

    context 'with a valid short message "ok"' do
      let(:content) { 'ok' }

      it { is_expected.not_to be_skip }
    end

    context 'with a valid message "quero o cardápio"' do
      let(:content) { 'quero o cardápio' }

      it { is_expected.not_to be_skip }
    end

    context 'with a valid two-digit code' do
      let(:content) { '10' }

      it { is_expected.not_to be_skip }
    end

    context 'with "kkkk" (laughter)' do
      let(:content) { 'kkkk' }

      it { is_expected.not_to be_skip }
    end

    context 'with "pix"' do
      let(:content) { 'pix' }

      it { is_expected.not_to be_skip }
    end

    context 'with "sim"' do
      let(:content) { 'sim' }

      it { is_expected.not_to be_skip }
    end
  end

  describe '#normalized' do
    it 'lowercases and collapses whitespace' do
      f = described_class.new('  QUERO O  CARDÁPIO  ')
      expect(f.normalized).to eq('quero o cardápio')
    end
  end
end
