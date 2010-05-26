class RDF::Query
  class Variable
    
    attr_reader :modifier

    def initialize(name = nil, value = nil)
      name = 'v%s' % rand(100000) if name.nil?    
      @name, @values = name.to_sym, []
      @strict = true
      bind(value) unless value.nil?
    end
    
    def unbound?
      @values.empty?
    end
    
    def literal?
      value.class == String && values.length == 1 && modifier == "="
    end
    
    def value
      @values.first.nil? ? nil : @values.first.last
    end
    
    def values
      @values.dup
    end
    
    def bind(value, modifier = "=", strict = true)
      value = if value.respond_to?(:object)
        value.object
      else
        value
      end

      @modifier = case modifier
        when :eq then "="
        when :nq then "!="
        when :lt then "<"
        when :lte then "<="
        when :gt then ">"
        when :gte then ">="
        else modifier
      end
      
      @strict = strict
      add(value, modifier)
    end
    
    def strict?
      @strict
    end

    def to_s
      unbound? ? "?#{name}" : "#{name}#{modifier}#{value}"
    end
    
    private
    
    def add(value, modifier)
      new_value = [modifier, value]
      unless @values.include?(new_value)
        @values << new_value
      end
      @values.last
    end
    
  end
end
