module Moribus
  # Declares a set of helper methods for more efficient use of aggregated
  # and tracked models.
  module Macros
    # For each of the passed arguments, which may either be method or
    # association names, define its delegation to the specified association.
    # If it responds to the effective reader, delegate to it.
    # If the subject of delegation is a method name, delegate both reader and writer.
    # If the subject of delegation is an association name, and the association
    # was defined via the +has_aggregated+ helper method, include the
    # association's delegation module, effectively using attribute readers,
    # and write the associated object. See the example below for a more
    # expressive explanation:
    #
    #   class CustomerAttributes < ActiveRecord::Base
    #     # has date_of_birth and is_military attributes
    #     acts_as_aggregated
    #   end
    #
    #   class PersonName < ActiveRecord::Base
    #     # has first_name and last_name attributes
    #     acts_as_aggregated
    #   end
    #
    #   class CustomerInfo < ActiveRecord::Base
    #     belongs_to :customer, :inverse_of => :customer_info
    #
    #     has_aggregated :customer_attributes
    #     has_aggregated :person_name
    #     acts_as_tracked
    #   end
    #
    #   class Customer < ActiveRecord::Base
    #     has_one_current :customer_info, :inverse_of => :customer
    #
    #     delegate_associated :customer_attributes, :person_name, :to => :customer_info
    #   end
    #
    #   customer = Customer.new
    #   info = customer.effective_customer_info
    #
    #   # note here we're skipping info.person_name building for readers and writers.
    #   info.first_name # => nil
    #   info.first_name = 'John'
    #   info.date_of_birth = Date.today
    #
    #   customer.first_name # => 'John'
    #   customer.is_military = true
    #   customer.is_military == info.is_military # => true
    #   info.is_military == info.customer_attributes.is_military # => true
    def delegate_associated(*args)
      options = args.extract_options!
      name = options[:to] or raise ArgumentError.new(":to option should be provided")
      include Extensions::DelegateAssociated unless self < Extensions::DelegateAssociated
      effective_name = "effective_#{name}".to_sym.in?(instance_methods(false)) ? "effective_#{name}" : name
      klass = reflect_on_association(name).klass

      args.each do |association_name|
        delegate(association_name, :to => effective_name)

        if (association_reflection = klass.reflect_on_association(association_name)).present?
          self.classes_delegating_to += [association_reflection.klass]
          if association_reflection.respond_to?(:delegated_attribute_methods)
            delegate("effective_#{association_name}", :to => effective_name)
            include association_reflection.delegated_attribute_methods
          else
            delegate :"#{association_name}=", :to => effective_name
          end
        else
          delegate :"#{association_name}=", :to => effective_name
        end
      end
    end

    # Define a +has_one+ association with `{ where(is_current: true) }`
    # as scope. Also define acceptance of nested attributes for
    # association and effective reader.
    def has_one_current(name, scope = nil, options = {})
      options = scope if scope.is_a?(Hash)

      current_scope = -> { where(is_current: true).order(id: :desc) }

      if scope.is_a?(Proc)
        prev_scope = scope
        if instance_exec(&prev_scope).order_values.any?
          scope = proc { instance_exec(&prev_scope).merge(-> { where(is_current: true) })  }
        else
          scope = proc { instance_exec(&prev_scope).merge(current_scope)  }
        end
      else
        scope = current_scope
      end

      reflection = has_one(name, scope, **options)
      reflection = normalize_reflection(reflection, name)
      reflection.options[:is_current] = true
      accepts_nested_attributes_for name
      define_effective_reader_for name
      alias_association :"current_#{name}", name
      reflection
    end
    private :has_one_current

    # Defines +belongs_to+ association, acceptance of nested attributes for it,
    # defines effective reader for associated object, and extends association
    # by special aggregated functionality (attribute delegation. See
    # Extensions::HasAggregatedExtension)
    def has_aggregated(name, options = {})
      reflection = belongs_to(name, **options)
      reflection = normalize_reflection(reflection, name)
      reflection.options[:aggregated] = true
      accepts_nested_attributes_for name
      define_effective_reader_for name
      extend_has_aggregated_reflection(reflection)
      reflection
    end
    private :has_aggregated

    # Normalize reflection for Rails 4.1/4.2.
    def normalize_reflection(reflection, name)
      return reflection unless reflection.respond_to? :[]

      # simplecov:disable unreachable on Rails >= 5, where reflections no longer respond to :[]
      if reflection.has_key?(name)
        # Rails 4.1
        reflection[name]
      else
        # Rails 4.2
        reflection["#{name}"]
      end
      # simplecov:enable
    end
    private :normalize_reflection

    # Declare a reader that will build associated object if it does not exist.
    # We can actually extend an association's readers like:
    #
    #   def reader
    #     super || build
    #   end
    #
    # But this corrupts the has_one association's create_other method
    # (and I failed to dig out why --a.kuzko). Also, this will result in
    # failing `it { should validate_presence_of :other }` specs, since
    # auto-building will prevent `nil` values that are used by specs.
    def define_effective_reader_for(name)
      class_eval <<-eoruby, __FILE__, __LINE__
        def effective_#{name}; #{name} || build_#{name}; end
      eoruby
    end
    private :define_effective_reader_for
  end
end
