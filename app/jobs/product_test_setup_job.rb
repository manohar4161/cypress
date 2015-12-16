class ProductTestSetupJob < ActiveJob::Base
  queue_as :product_test_setup

  def perform(product_test)
    product_test.generate_records if product_test.records.count == 0
    product_test.archive_records if product_test.patient_archive.filename.nil?

    MeasureEvaluationJob.perform_now(product_test, {})
  end
end