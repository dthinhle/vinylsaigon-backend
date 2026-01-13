class ProductFlagsFormatterService
  def self.call(flags:, free_installment_fee:)
    new(flags: flags, free_installment_fee: free_installment_fee).call
  end

  def initialize(flags:, free_installment_fee:)
    @flags = (flags || []).map(&:parameterize)
    @free_installment_fee = free_installment_fee
  end

  def call
    handle_free_shipping
    handle_installment_plan
    @flags
  end

  private

  def handle_free_shipping
    if @flags.include?('not-free-shipping')
      @flags.delete('not-free-shipping')
    else
      @flags << 'free-shipping'
    end
  end

  def handle_installment_plan
    if @free_installment_fee
      @flags << 'installment-plan'
    end
  end
end
