require 'test_helper'
require 'fileutils'

class RecordFilterTest < ActiveSupport::TestCase
  def setup
    bundle = FactoryGirl.create(:static_bundle)
    @all_records = Record.all
  end

  def test_filter_gender
    selected_gender = %w(M F).sample
    filters = { 'genders' => [selected_gender] }

    filtered_records = Cypress::RecordFilter.filter(@all_records, filters, {}).to_a

    @all_records.each do |r|
      if filtered_records.include? r
        assert_equal(selected_gender, r.gender, 'Filtered record set includes a record that does not match criteria')
      else
        assert_not_equal(selected_gender, r.gender, 'Filtered record set does not include a record that matches criteria')
      end
    end
  end

  def test_filter_race
    selected_race = %w(2106-3 2028-9 2054-5).sample
    filters = { 'races' => [selected_race] }

    filtered_records = Cypress::RecordFilter.filter(@all_records, filters, {}).to_a

    @all_records.each do |r|
      if filtered_records.include? r
        assert_equal(selected_race, r.race['code'], 'Filtered record set includes a record that does not match criteria')
      else
        assert_not_equal(selected_race, r.race['code'], 'Filtered record set does not include a record that matches criteria')
      end
    end
  end

  def test_filter_ethnicity
    selected_ethn = %w(2186-5 2135-2).sample

    filters = { 'ethnicities' => [selected_ethn] }

    filtered_records = Cypress::RecordFilter.filter(@all_records, filters, {}).to_a

    @all_records.each do |r|
      if filtered_records.include? r
        assert_equal(selected_ethn, r.ethnicity['code'], 'Filtered record set includes a record that does not match criteria')
      else
        assert_not_equal(selected_ethn, r.ethnicity['code'], 'Filtered record set does not include a record that matches criteria')
      end
    end
  end

  def test_filter_age_max
    ## reminder: for dates, > means later/younger...
    now = Time.now.in_time_zone

    target_age = Random.rand(100)

    filters = { 'age' => { 'max' => target_age } }

    filtered_records = Cypress::RecordFilter.filter(@all_records, filters, effective_date: now.to_i).to_a

    validate_record_count(@all_records, filtered_records)

    @all_records.each do |r|
      dob = Time.at(r.birthdate).in_time_zone
      patient_age = age_on_date(dob, now)

      if filtered_records.include? r
        assert(patient_age <= target_age, 'Filtered record set includes a record that does not match criteria')
      else
        assert(patient_age > target_age, 'Filtered record set does not include a record that matches criteria')
      end
    end
  end

  def test_filter_age_targeted
    # Pick a patient, get their age, filter by that age
    # and make sure the patient is in the results
    now = Time.now.in_time_zone
    patient = @all_records.sample
    dob = Time.at(patient.birthdate).in_time_zone
    target_age = age_on_date(dob, now)

    filters = { 'age' => { 'max' => target_age } }

    filtered_records = Cypress::RecordFilter.filter(@all_records, filters, effective_date: now.to_i).to_a

    assert filtered_records.include?(patient), 'Targeted patient not included in filtered results'
  end

  def test_filter_age_min
    ## reminder: for dates, > means later/younger...
    now = Time.now.in_time_zone

    target_age = Random.rand(100)

    filters = { 'age' => { 'min' => target_age } }

    filtered_records = Cypress::RecordFilter.filter(@all_records, filters, effective_date: now.to_i).to_a

    validate_record_count(@all_records, filtered_records)

    @all_records.each do |r|
      dob = Time.at(r.birthdate).in_time_zone
      patient_age = age_on_date(dob, now)

      if filtered_records.include? r
        assert(patient_age >= target_age, 'Filtered record set includes a record that does not match criteria')
      else
        assert(patient_age < target_age, 'Filtered record set does not include a record that matches criteria')
      end
    end
  end

  def test_filter_age_edge_case_inclusive
    # the "edge case" for age filtering is when the patient's birthdate is on the effective date

    patient = @all_records.sample
    birthdate = Time.at(patient.birthdate).in_time_zone

    # CASE 1
    age = Random.rand(100)
    effective_date = Time.local(birthdate.year + age, birthdate.month, birthdate.day, 0, 0, 0).in_time_zone

    filters = { 'age' => { 'min' => age } }
    filtered_records = Cypress::RecordFilter.filter(@all_records, filters, effective_date: effective_date).to_a

    assert filtered_records.include? patient

    # CASE 2
    age = Random.rand(100)
    effective_date = Time.local(birthdate.year + age, birthdate.month, birthdate.day, 0, 0, 0).in_time_zone

    filters = { 'age' => { 'max' => age } }
    filtered_records = Cypress::RecordFilter.filter(@all_records, filters, effective_date: effective_date).to_a

    assert filtered_records.include? patient
  end

  def test_filter_age_edge_case_exclusive
    patient = @all_records.sample
    birthdate = Time.at(patient.birthdate).in_time_zone

    # CASE 1
    age = Random.rand(100)
    effective_date = Time.local(birthdate.year + age, birthdate.month, birthdate.day, 0, 0, 0).in_time_zone

    filters = { 'age' => { 'min' => age + 1 } }
    filtered_records = Cypress::RecordFilter.filter(@all_records, filters, effective_date: effective_date).to_a

    assert_not filtered_records.include?(patient)

    # CASE 2
    age = Random.rand(100)
    effective_date = Time.local(birthdate.year + age, birthdate.month, birthdate.day, 0, 0, 0).in_time_zone

    filters = { 'age' => { 'max' => age - 1 } }
    filtered_records = Cypress::RecordFilter.filter(@all_records, filters, effective_date: effective_date).to_a

    assert_not filtered_records.include?(patient)
  end

  # helper function to calculate age
  def age_on_date(dob, now)
    now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)
  end

  def test_filter_payer
    selected_payer = %w(Medicaid Medicare Other).sample
    filters = { 'payers' => [selected_payer] }

    filtered_records = Cypress::RecordFilter.filter(@all_records, filters, {}).to_a
    @all_records.each do |r|
      if filtered_records.include? r
        assert(record_has_payer?(r, selected_payer), 'Filtered record set includes a record that does not match criteria')
      else
        assert_not(record_has_payer?(r, selected_payer), 'Filtered record set does not include a record that matches criteria')
      end
    end
  end

  def record_has_payer?(record, payer)
    all_payers = record.insurance_providers.collect { |ip| ip.payer.name }
    all_payers.include? payer
  end

  def test_filter_problem
    selected_problem = %w(1.2.3.4).sample

    filters = { 'problems' => { oid: [selected_problem], hqmf_ids: ['2.16.840.1.113883.3.560.1.2'] } }

    filtered_records = Cypress::RecordFilter.filter(@all_records, filters, bundle_id: @all_records.first.bundle_id).to_a

    code_sets = HealthDataStandards::SVS::ValueSet.where('oid' => selected_problem).pluck('concepts')

    relevant_codes = []
    code_sets.each do |code_set|
      code_set.each do |code|
        # problems come from SNOMED, per the rule
        relevant_codes << code['code'] if code['code_system'] == '2.16.840.1.113883.6.96'
      end
    end

    relevant_codes.uniq!

    @all_records.each do |r|
      if filtered_records.include? r
        assert(record_has_problem?(r, relevant_codes), 'Filtered record set includes a record that does not match criteria')
      else
        assert_not(record_has_problem?(r, relevant_codes), 'Filtered record set does not include a record that matches criteria')
      end
    end
  end

  def record_has_problem?(record, code_set)
    search_fields = [record.conditions, record.encounters, record.procedures]

    search_fields.each do |search_field|
      next unless search_field
      search_field.each do |item|
        if item.codes && item.codes['SNOMED-CT'] && (item.codes['SNOMED-CT'] & code_set) != []
          return true
        end
      end
    end

    false
  end

  def test_provider_filter
    filter_record = @all_records.sample
    prov = Provider.find(filter_record.provider_performances.first.provider_id)
    prov_filters = { 'npis' => [prov.npi], 'tins' => [prov.tin] }
    filters = { 'providers' => prov_filters }
    filtered_records = Cypress::RecordFilter.filter(@all_records, filters, {}).to_a

    assert filtered_records.include?(filter_record), 'should include the targeted patient in results'
  end

  def validate_record_count(all_records, filtered_records, expected_count = -1)
    assert(all_records.count >= filtered_records.count, 'Filtered set of records is larger than original Unfiltered set')

    if expected_count > -1
      assert_equal(expected_count, filtered_records.count, 'Filtered set of records does not match expected count')
    end
  end
end
