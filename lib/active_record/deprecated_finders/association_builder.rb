require 'active_record/associations/builder/association'
require 'active_support/core_ext/module/aliasing'
require 'active_support/deprecation'

module ActiveRecord::Associations::Builder
  class DeprecatedOptionsProc
    attr_reader :options, :initial_scope

    def initialize(options, initial_scope)
      options[:includes]  = options.delete(:include)    if options[:include]
      options[:where]     = options.delete(:conditions) if options[:conditions]

      @initial_scope = initial_scope.respond_to?(:call) ? initial_scope : nil
      @options = options
    end

    def to_proc
      options = self.options
      initial_scope = self.initial_scope
      proc do |owner|
        if options[:where].respond_to?(:to_proc)
          context = owner || self
          where(context.instance_eval(&options[:where]))
            .merge!(options.except(:where)).merge(initial_scope)
        else
          merge(options).merge(initial_scope)
        end
      end
    end

    def arity
      1
    end
  end

  class Association
    DEPRECATED_OPTIONS = [:readonly, :order, :limit, :group, :having,
                          :offset, :select, :uniq, :include, :conditions]

    self.valid_options += [:select, :conditions, :include, :readonly]

    def initialize_with_deprecated_options(model, name, scope, options)
      options            = scope if scope.is_a?(Hash)
      deprecated_options = options.slice(*DEPRECATED_OPTIONS)

      unless deprecated_options.empty?
        ActiveSupport::Deprecation.warn(
          "The following options in your #{model.name}.#{macro} :#{name} declaration are deprecated: " \
          "#{deprecated_options.keys.map(&:inspect).join(',')}. Please use a scope block instead. " \
          "For example, the following:\n" \
          "\n" \
          "    has_many :spam_comments, conditions: { spam: true }, class_name: 'Comment'\n" \
          "\n" \
          "should be rewritten as the following:\n" \
          "\n" \
          "    has_many :spam_comments, -> { where spam: true }, class_name: 'Comment'\n"
        )
        scope   = DeprecatedOptionsProc.new(deprecated_options, scope)
        options = options.except(*DEPRECATED_OPTIONS)
      end

      initialize_without_deprecated_options(model, name, scope, options)
    end

    alias_method_chain :initialize, :deprecated_options
  end

  class CollectionAssociation
    include Module.new {
      def valid_options
        super + [:order, :group, :having, :limit, :offset, :uniq]
      end
    }
  end
end
