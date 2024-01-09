module Moribus
  # Adds aggregated behavior to a model. An aggregated model tries to insure
  # it will not duplicate itself for whatever parents it belongs to. Whenever
  # an aggregated model is about to be saved, it uses its attributes to
  # perform a lookup for an existing record with the same attributes. If the
  # lookup succeeds, its id is used to replace id of model being saved, and
  # no 'INSERT' statement is executed. If the lookup fails, the original AR
  # save routines are performed.
  #
  # This behavior ignores by default the columns it doesn't consider to
  # contain content such as the ones created and used by ActiveRecord. These
  # can be expanded through the API:
  # @example:
  #   acts_as_aggregated :non_content_columns => %w(some other colums)
  module AggregatedBehavior
    extend ActiveSupport::Concern

    included do
      # specifies a list of attributes to exclude from lookup
      class_attribute :aggregated_behaviour_non_content_columns, :instance_writer => false
      self.aggregated_behaviour_non_content_columns = %w(id created_at updated_at lock_version)
    end

    # Override the original AR::Base #save method with the aggregated
    # behavior. This cannot be done using a before_save callback, because, if
    # the lookup succeeds, we don't want the original #save to be executed.
    # But if +false+ is returned by the callback, it will also be returned
    # by the #save method, wrongly indicating the result of saving.
    def save(**)
      @updated_as_aggregated = false
      run_callbacks(:save) do
        return (lookup_self_and_replace or super) if new_record?

        is_any_content_attr_changed =
          attributes.except(*aggregated_behaviour_non_content_columns).keys.
            any?{ |attr| attribute_changed?(attr) }

        if is_any_content_attr_changed
          to_new_record!
          lookup_self_and_replace or return super

          true
        else
          super
        end
      end
    end

    # Bang version of #save.
    def save!(**kwargs)
      save(**kwargs) or raise_record_not_saved_error
    end

    # Raise "record not saved".
    def raise_record_not_saved_error
      args =
        (Rails::VERSION::MAJOR == 4 && Rails::VERSION::MINOR < 2) ? [] : ["Failed to save record"]

      raise ActiveRecord::RecordNotSaved, *args
    end
    private :raise_record_not_saved_error

    # Use the +lookup_relation+ to get the very first existing record that
    # corresponds to +self+.
    def lookup_self
      lookup_relation.first
    end
    private :lookup_self

    # Use the attributes of +self+ to generate a relation that corresponds to
    # the existing record in the table with the same attributes.
    def lookup_relation
      self.class.unscoped.where(attributes.except(*aggregated_behaviour_non_content_columns))
    end
    private :lookup_relation

    # If #lookup_self successfully returns a record, 'replace' +self+ by it
    # (using its id, created_at, updated_at values).
    def lookup_self_and_replace
      @updated_as_aggregated = true
      existing               = lookup_self

      if existing.present? then
        to_persistent!(existing)
      end
    end
    private :lookup_self_and_replace
  end
end
