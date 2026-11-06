require 'power_enum'

# Introduces Aggregated and Tracked behavior to ActiveRecord::Base models, as well
# as Macros and Extensions modules for more efficient usage. Effectively replaces
# both Aggregatable and Trackable modules.
module Moribus
  extend ActiveSupport::Concern
  extend ActiveSupport::Autoload

  autoload :AliasAssociation
  autoload :AggregatedBehavior
  autoload :AggregatedCacheBehavior
  autoload :TrackedBehavior
  autoload :Macros
  autoload :Extensions

  included do
    class_attribute :tracked_parent_relations, instance_accessor: false

    include AliasAssociation
    include Extensions
    extend Macros
  end

  # :nodoc:
  module ClassMethods
    # Resolve keys after associations are declared, without caching incomplete results.
    def parent_relation_keys
      get_parent_relation_keys(tracked_parent_relations)
    end

    # Adds aggregated behavior to a model.
    def acts_as_aggregated(options = {})
      options.symbolize_keys!

      options.assert_valid_keys(:cache_by, :non_content_columns)
      include AggregatedBehavior

      if options[:cache_by].present?
        @aggregated_caching_column = options[:cache_by]
        include AggregatedCacheBehavior
      end

      if options[:non_content_columns]
        self.aggregated_behaviour_non_content_columns += Array.wrap(options[:non_content_columns]).map(&:to_s)
      end
    end
    private :acts_as_aggregated

    # Adds tracked behavior to a model
    def acts_as_tracked(options = {})
      options.symbolize_keys!

      options.assert_valid_keys(:preceding_key, :by)
      include TrackedBehavior

      @preceding_key_column = options[:preceding_key]
      self.tracked_parent_relations = options[:by]
    end
    private :acts_as_tracked

    # Return +true+ if self was declared as +acts_as_aggregated+.
    def acts_as_aggregated?
      self < AggregatedBehavior
    end

    # Return +true+ if self was declared as +acts_as_tracked+.
    def acts_as_tracked?
      self < TrackedBehavior
    end

    # Return array of parent relation foreign keys, which is used for lock_version calculation.
    #
    # @param parent [Symbol,Array<Symbol>]
    # @return [Array<String>]
    def get_parent_relation_keys(parent)
      parents = Array(parent)

      reflect_on_all_associations.inject([]) do |result, relation|
        result << relation.foreign_key if parents.include?(relation.name)

        result
      end
    end
    private :get_parent_relation_keys
  end

  # Marks +self+ as a new record. Sets +id+ attribute to nil, but memorizes
  # the old value in case of exception.
  def to_new_record!
    store_before_to_new_record_values
    reset_persistence_values
    @new_record = true
  end

  # Marks +self+ as persistent record. If another record is passed, uses its
  # persistence attributes (id, timestamps). If nil is passed as an argument,
  # marks +self+ as persisted record and sets +id+ to memorized value.
  def to_persistent!(existing = nil)
    if existing
      self.id         = existing.id
      self.created_at = existing.created_at if respond_to?(:created_at)
      self.updated_at = existing.updated_at if respond_to?(:updated_at)

      clear_changes_information
    else
      restore_before_to_new_record_values

      clear_attribute_change(:created_at) if respond_to?(:created_at)
      clear_attribute_change(:updated_at) if respond_to?(:updated_at)
    end
    @new_record = false
    true
  end

  # Stores original record id for tracking purposes.
  def set_parent
    tbc = self.class.preceding_key_column
    if tbc && self.respond_to?(tbc)
      write_attribute(tbc, @_before_to_new_record_values[:id])
    end
  end

  # Helper method used by has_aggregated (in fact, belongs_to)
  # association during autosave.
  def updated_as_aggregated?
    !!@updated_as_aggregated
  end

  # Save persistence values of id, updated_at and created_at to instance
  # variable to have an ability to set them back if object fails to
  # be saved.
  def store_before_to_new_record_values
    values = {:id => id}
    values[:updated_at] = updated_at if respond_to?(:updated_at)
    values[:created_at] = created_at if respond_to?(:created_at)
    @_before_to_new_record_values = values
  end
  private :store_before_to_new_record_values

  # Set persistence values of id, updated_at and created_at back.
  def restore_before_to_new_record_values
    values = @_before_to_new_record_values
    self.id = values[:id]
    self.created_at = values[:created_at] if respond_to?(:updated_at=)
    self.updated_at = values[:updated_at] if respond_to?(:updated_at=)
  end
  private :restore_before_to_new_record_values

  # Set id, updated_at and created_at to nil in order to
  # update them when new record is created.
  def reset_persistence_values
    self.id = nil

    if respond_to?(:updated_at=)
      self.updated_at = nil
      self.updated_at_will_change!
    end

    if respond_to?(:created_at=)
      self.created_at = nil
      self.created_at_will_change!
    end

    # mark all other attributes is changing
    (attributes.keys - changes.keys).each{ |key| self.send(:"#{key}_will_change!") }
  end
  private :reset_persistence_values
end

ActiveRecord::Base.class_eval do
  include Moribus
end
