module RDF::SPARQL
  class Reader < RDF::Reader

    include RDF::SPARQL::Common
    format RDF::SPARQL::Format
    
    RE_PREFIX     = /^PREFIX\s([a-z]+):\s<([^>]+)>\s?/
    RE_SELECT     = /^SELECT\s/
    RE_DESCRIBE   = /^DESCRIBE\s/
    RE_FLAG       = /^(DISTINCT|REDUCED|)\s?/
    RE_WHERE      = /^(WHERE|)\s?\{/
    RE_TRIPLE_END = /^([\.|,|;])\s?/
    RE_FILTER     = /^FILTER\s*\(\s?/
    RE_FILTER_MOD = /^(\|{2}|&{2})+\s?/
    RE_FILTER_END = /^\)\s?/
    RE_COMPARISON = /^([!=|>|<|=])\s?/
    RE_TYPE_A     = /^(a)\s?/
    RE_FULL_URI   = /^<([^>]+)>\s?/
    RE_NS_URI     = /^([a-zA-Z]+):([a-zA-Z]+)\s?/
    RE_VARIABLE   = /^\?([A-Za-z0-9_]+)\s?/
    RE_LITERAL    = /^"([^"]*)"\s?/
    RE_LANGUAGE   = /^@([a-z]+[\-a-z0-9]*)\s?/
    RE_DATATYPE   = /^(\^\^)\s?/
    RE_NUMERIC    = /^([\d\.]+)\s?/
    
    ##
    # @param  [IO, File, String] input
    # @yield  [reader]
    # @yieldparam [Reader] reader
    ##
    def initialize(input = $stdin, options = {}, &block)
      @line = input.respond_to?(:read) ? input.read : input
      @line.gsub!(/[\r\n]/, ' ').squeeze!(' ')
      @graph = RDF::Graph.new
      @type = nil
      @prefixes = {}
      @variables = {}
      @targets = []
      @options = {}
      read_all
      block.call(self) if block_given?
    end
    
    private
    
    ##
    # Main parser loop: reads prologue, conditions and epilogue.
    # @return [True]
    ##
    def read_all #nodoc
      read_prologue && read_where && read_epilogue
    end
    
    ##
    # Attempts to read prologue.
    # @return [True]
    ##
    def read_prologue
      while (read_prefix || read_query); end
      true
    end
    
    ##
    # Attempts to read prefixes.
    # @return [nil] if not found
    # @return [String] if found
    ##
    def read_prefix
      ns, uri = match(RE_PREFIX)
      ns.nil? ? nil : add_prefix(ns, uri)
    end
    
    ##
    # Attempts to read query.
    # @return [nil] if not found
    # @return [Symbol] if found
    ##
    def read_query
      read_select_query || read_describe_query || read_construct_query || read_ask_query
    end
    
    ##
    # Attempts to read requested variables.
    # @return [True]
    ##
    def read_query_variables
      while
        variable = read_variable
        break if variable.nil?
        add_target(variable)
      end
      true
    end
    
    ##
    # Attempts to read a `SELECT` query.
    # @return [nil] if not found
    # @return [Symbol] if found
    ##
    def read_select_query
      unless match(RE_SELECT)
        return nil
      end
      case match(RE_FLAG)
        when 'DISTINCT' then @options[:distinct] = true
        when 'REDUCED'  then @options[:reduced] = true
      end
      read_query_variables
      @type = :select
    end
    
    ##
    # Attempts to read a `DESCRIBE` query.
    # @return [nil] if not found
    # @return [Symbol] if found
    ##
    def read_describe_query
      unless match(RE_DESCRIBE)
        return nil
      end
      read_query_variables
      @type = :describe
    end
    
    ##
    # Attempts to read a `CONSTRUCT` query.
    # @return [nil] if not found
    # @return [Symbol] if found
    ##
    def read_construct_query
      # TODO
      return nil
      @type = :construct
    end
    
    ##
    # Attempts to read an `ASK` query.
    # @return [nil] if not found
    # @return [Symbol] if found
    ##
    def read_ask_query
      # TODO
      return nil
      @type = :ask
    end
    
    ##
    # Reads all triples & filters.
    # @return [nil] if not found
    # @return [True] if found
    ##
    def read_where
      return nil unless match(RE_WHERE)
      while (read_triple || read_filter); end
      true
    end
    
    ##
    # Attempts to read a triple.
    # @return [nil] if not found
    # @return [RDF::Query::Pattern] if found
    ##
    def read_triple
      shortcut =    read_triple_ending
      @subject =    (read_variable || read_uri)   if shortcut == '.'
      @predicate =  (read_variable || read_uri)   if shortcut != ','
      @object =     (read_variable || read_uri || read_literal)
      return nil if @subject.nil?
      add_triple(@subject, @predicate, @object)
    end
    
    ##
    # Returns triple's last character.
    # @return [String]
    ##
    def read_triple_ending
      symbol = match(RE_TRIPLE_END)
      symbol.nil? ? '.' : (symbol.empty? ? '.' : symbol)
    end
    
    ##
    # Attempts to read a filter.
    # @return [nil] if not found
    # @return [True] if found
    ##
    def read_filter
      return nil unless match(RE_FILTER)
      while (read_filter_condition || read_filter_ending); end
      true
    end
    
    ##
    # Attempts to read next condition in a filter.
    # @return [nil] if not found
    # @return [True] if found
    ##
    def read_filter_condition
      modifier =    read_filter_modifier
      variable =    read_variable
      comparison =  read_comparison_operator
      value =       (read_variable || read_literal || read_numeric)
      return nil if variable.nil?
      variable.bind(value, comparison, (modifier != "||"))
      true
    end
    
    ##
    # Attempts to read `FILTER` modifier (|| or &&).
    # @return [nil] if not found
    # @return [String] if found
    ##
    def read_filter_modifier
      match(RE_FILTER_MOD)
    end
    
    ##
    # Attempts to read then end of `FILTER` expression.
    # @return [nil] if not found
    # @return [String] if found
    ##
    def read_filter_ending
      match(RE_FILTER_END)
    end
    
    ##
    # Attempts to read comparison operator (> < != =).
    # @return [nil] if not found
    # @return [String] if found
    ##
    def read_comparison_operator
      match(RE_COMPARISON)
    end
    
    ##
    # Attempts to read query epilogue (order, limit, group).
    # @return [True]
    ##
    def read_epilogue
      # TODO
      true
    end
    
    ##
    # Attempts to read an URI (full, namespaced or RDF type shortcut).
    # @return [nil] if not found
    # @return [RDF::URI] if found
    ##
    def read_uri
      read_full_uri || read_type_shortcut || read_ns_uri
    end
    
    ##
    # Attempts to read an RDF type shortcut.
    # @return [nil] if not found
    # @return [RDF::URI] if found
    ##
    def read_type_shortcut
      symbol = match(RE_TYPE_A)
      symbol.nil? ? nil : (symbol == 'a' ? RDF.type : nil)
    end
    
    ##
    # Attempts to read a non-abridged URI (no shortcuts or namespaces).
    # @return [nil] if not found
    # @return [RDF::URI] if found
    ##
    def read_full_uri
      uri = match(RE_FULL_URI)
      uri.nil? ? nil : RDF::URI.new(uri)
    end
    
    ##
    # Attempts to read a namespaced URI.
    # @return [nil] if not found
    # @return [RDF::URI] if found
    ##
    def read_ns_uri
      ns, uri = match(RE_NS_URI)
      ns.nil? ? nil : RDF::URI.new(@prefixes[ns].to_s + uri)
    end
    
    ##
    # Attempts to reads a variable.
    # @return [nil] if not found
    # @return [RDF::Query::Variable] if found
    ##
    def read_variable
      name = match(RE_VARIABLE)
      name.nil? ? nil : add_variable(name)
    end
    
    ##
    # Attempts to read a literal value.
    # @return [nil] if not found
    # @return [RDF::Literal] if found
    ##
    def read_literal
      string = match(RE_LITERAL)
      return nil if string.nil?
      language = match(RE_LANGUAGE)
      if language
        RDF::Literal.new(string, :language => language)
      elsif match(RE_DATATYPE)
        RDF::Literal.new(string, :datatype => read_uri)
      else
        RDF::Literal.new(string)
      end
    end
    
    ##
    # Attempts to read a numeric value.
    # @return [nil] if not found
    # @return [Float] if found
    ##
    def read_numeric
      value = match(RE_NUMERIC)
      value.nil? ? nil : value.to_f
    end
    
    ##
    # Adds a triple.
    # @param [RDF::URI, RDF::Query::Variable] subject
    # @param [RDF::URI, RDF::Query::Variable] predicate
    # @param [RDF::URI, RDF::Query::Variable, RDF::Literal] object
    # @return [RDF::Query::Pattern]
    ##
    def add_triple(subject, predicate, object)
      @graph << RDF::Query::Pattern.new(subject, predicate, object)
    end

    ##
    # Adds a prefix.
    # @param [String] namespace
    # @param [String] uri
    # @return [String]
    ##
    def add_prefix(namespace, uri)
      @prefixes[namespace] = uri
    end
    
    ##
    # Adds a variable.
    # @param [String] name
    # @return [RDF::Query::Variable]
    ##
    def add_variable(name)
      @variables[name] ||= RDF::Query::Variable.new(name)
    end

    ##
    # Adds a target.
    # @param [RDF::Query::Variable] variable
    # @return [Array<RDF::Query::Variable>]
    ##
    def add_target(variable)
      @targets << variable
    end
    
    ##
    # Returns a match array.
    # @param [Regexp] pattern
    # @return [nil, String, Array<String>]
    ##
    def match(pattern)
      if (@line =~ pattern)
        @line = $'.lstrip
        result = Regexp.last_match.to_a[1,10]
        case result.length
          when 0 then true
          when 1 then result.first
          else result
        end
      end
    end
    
  end
end
