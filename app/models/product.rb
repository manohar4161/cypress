class Product
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic
  include Mongoid::Timestamps

  belongs_to :vendor, index: true, touch: true
  has_many :product_tests, :dependent => :destroy
  accepts_nested_attributes_for :product_tests, allow_destroy: true
  # NOTE: more relationships must be defined

  field :name, type: String
  field :version, type: String
  field :description, type: String
  # field :ehr_type, type: String
  field :c1_test, type: Boolean
  field :c2_test, type: Boolean
  field :c3_test, type: Boolean
  field :c4_test, type: Boolean
  field :randomize_records, type: Boolean
  # field :measure_selection, type: String

  validates :name, presence: true,
                   uniqueness: { :scope => :vendor,
                                 :message => 'Product name was already taken. Please choose another.' }
  # validates :ehr_type, presence: true, inclusion: { in: %w(provider hospital) }
  validate :meets_required_certification_types?
  validates :vendor, presence: true

  def status
    Rails.cache.fetch("#{cache_key}/status") do
      total = product_tests.count
      if product_tests_failing.count > 0
        'failing'
      elsif product_tests_passing.count == total && total > 0
        'passing'
      else
        'incomplete'
      end
    end
  end

  def product_tests_passing
    Rails.cache.fetch("#{cache_key}/product_tests_passing") do
      product_tests.select { |product_test| product_test.status == 'passing' }
    end
  end

  def product_tests_failing
    Rails.cache.fetch("#{cache_key}/product_tests_failing") do
      product_tests.select { |product_test| product_test.status == 'failing' }
    end
  end

  def product_tests_incomplete
    Rails.cache.fetch("#{cache_key}/product_tests_incomplete") do
      product_tests.select { |product_test| product_test.status == 'incomplete' }
    end
  end

  def meets_required_certification_types?
    errors.add(:tests, 'Product must certify to C1 or C2 or both.') unless c1_test || c2_test
  end

  def at_least_one_measure?
    errors.add(:measure_tests, 'Product must specify least one measure for testing.') unless product_tests.any?
  end

  def measure_ids
    (product_tests.pluck(:measure_ids) || []).flatten.uniq
  end

  def add_product_tests_to_product(added_measure_ids = [])
    return if added_measure_ids.nil?
    new_ids = added_measure_ids - measure_ids
    to_remove_ids = measure_ids - added_measure_ids

    new_ids.each do |new_measure_id|
      measure = Measure.top_level.find_by(hqmf_id: new_measure_id)
      product_tests.build({ name: measure.name, product: self, measure_ids: [new_measure_id],
                            cms_id: measure.cms_id, bundle_id: measure.bundle_id }, MeasureTest)
    end

    to_remove_ids.each do |old_measure_id|
      product_tests.in(measure_ids: old_measure_id).destroy
    end
  end
end
