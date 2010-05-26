module RDF::SPARQL
  class Reader < RDF::Reader

    include RDF::SPARQL::Common
    format RDF::SPARQL::Format
    
    ##
    # @param  [IO, File, String] input
    # @yield  [reader]
    # @yieldparam [Reader] reader
    ##
    def initialize(input = $stdin, options = {}, &block)
      @line = input.respond_to?(:read) ? input.read : input
      @graph = RDF::Graph.new
      @type = nil
      @prefixes = {}
      @variables = {}
      @targets = []
      @options = {}
      read_query
      block.call(self) if block_given?
    end
    
    private
    
      
    ##
    # Reads prologue of SPARQL query (prefixes and targets)
    ##
    def read_prologue
      while (read_prefix || read_target); end
    end
    
    ##
    # Reads next `PREFIX`
    ##
    def read_prefix
      full, ns, uri = match(/\s*PREFIX\s+([a-z]+):\s+<([^>]+)>/)
      full.nil? ? nil : add_prefix(ns, uri)
    end
    
    ##
    # Reads targets of SPARQL query
    ##
    def read_target
      read_select_target || read_describe_target || read_construct_target || read_ask_target
    end
    
    ##
    # Reads targets of a `SELECT` query
    ##
    def read_select_target
      full, flag = match(/\s*SELECT\s+(DISTINCT|REDUCED|)\s*/)
      return nil if full.nil?
      case flag
        when 'DISTINCT' then @options[:distinct] = true
        when 'REDUCED'  then @options[:reduced] = true
      end
      @type = :select
      while 
        var = read_variable
        var.nil? ? break : add_target(var)
      end
    end
    
    ##
    # Reads targets of a `DESCRIBE` query
    ##
    def read_describe_target
      return nil if match(/\s*DESCRIBE\s+/).nil?
      @type = :describe
      while
        var = (read_variable || read_uri)
        var.nil? ? break : add_target(var)
      end
    end
    
    ##
    # Reads targets of a `CONSTRUCT` query
    ##
    def read_construct_target
      return nil
      @type = :construct
    end
    
    ##
    # Reads targets of an `ASK` query
    ##
    def read_ask_target
      return nil
      @type = :ask
    end
    
    ##
    # Reads all triples & filters of a query
    ##
    def read_where
      full = match(/(WHERE|)\s*\{/)
      return nil if full.nil?
      while (read_triple || read_filter); end
    end
    
    ##
    # Main parser loop: reads prologue, conditions and epilogue
    ##
    def read_query #nodoc
      while (read_prologue || read_where || read_epilogue); end
    end
    
    ##
    # Reads a triple
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
    # Finds any formatting shortcuts (a comma, a semicolon)
    ##
    def read_triple_ending
      full, symbol = match(/\s*([\.|,|;])\s*/)
      full.nil? ? '.' : (symbol.empty? ? '.' : symbol)
    end

    ##
    # Reads a filter
    ##
    def read_filter
      full = match(/FILTER\s*\(\s*/)
      return nil if full.nil?
      while (read_filter_condition || read_filter_ending); end
    end
    
    ##
    # Reads next condition specified in a filter
    ##
    def read_filter_condition
      modifier =    read_filter_modifier
      variable =    read_variable
      comparison =  read_comparison_operator
      value =       (read_variable || read_literal || read_numeric)
      return nil if variable.nil?
      variable.bind(value, comparison, (modifier != "||"))
    end
    
    ##
    # Returns filter modifier (|| or &&)
    ##
    def read_filter_modifier
      full, symbols = match(/\s*(\|{2}|&{2})+\s*/)
      full.nil? ? nil : symbols
    end
    
    ##
    # Moves pointer to the end of `FILTER` expression
    ##
    def read_filter_ending
      match(/\s*\)\s*/)
    end
    
    ##
    # Returns comparison operator (> < != =)
    ##
    def read_comparison_operator
      full, symbol = match(/\s*([!=|>|<|=])\s*/)
      full.nil? ? nil : symbol
    end
    
    ##
    # Reads query epilogue (order, limit, group)
    ##
    def read_epilogue
      nil
    end
    
    ##
    # Reads next `PREFIX`
    ##
    def read_prefix
      full, ns, uri = match(/\s*PREFIX\s+([a-z]+):\s+<([^>]+)>/)
      full.nil? ? nil : add_prefix(ns, uri)
    end

    ##
    # Reads an URI (as a full URI, namespaced or RDF type shortcut)
    ##
    def read_uri
      read_full_uri || read_type_shortcut || read_ns_uri
    end
    
    ##
    # Returns RDF.type if URI is an RDF type shortcut
    ##
    def read_type_shortcut
      full, symbol = match(/\s*(a)\s*/)
      full.nil? ? nil : (symbol == 'a' ? RDF.type : nil)
    end
    
    ##
    # Returns URI if this is a non-abridged URI (no shortcuts or namespaces)
    ##
    def read_full_uri
      full, uri = match(/^<([^>]+)>/)
      full.nil? ? nil : RDF::URI.new(uri)
    end
    
    ##
    # Returns URI that was namespaced in prefixes
    ##
    def read_ns_uri
      full, ns, uri = match(/([a-zA-Z]+):([a-zA-Z]+)/)
      full.nil? ? nil : RDF::URI.new(@prefixes[ns].to_s + uri)
    end
    
    ##
    # Reads a variable
    ##
    def read_variable
      full, name = match(/\?([A-Za-z0-9_]+)\s*/)
      full.nil? ? nil : add_variable(name)
    end
    
    ##
    # Reads a literal value
    ##
    def read_literal
      full, string = match(/\s*"([^"]*)"/)
      return nil if full.nil?
      full, language = match(/@([a-z]+[\-a-z0-9]*)/)
      if language
        RDF::Literal.new(string, :language => language)
      elsif match(/(\^\^)/)
        RDF::Literal.new(string, :datatype => read_uri)
      else
        RDF::Literal.new(string)
      end
    end
    
    ##
    # Reads a numeric value
    ##
    def read_numeric
      full = match(/\d+/)
      full.nil? ? nil : full.first
    end

    ##
    # Registers a triple
    ##
    def add_triple(subject, predicate, object)
      @graph << RDF::Query::Pattern.new(subject, predicate, object)
    end

    ##
    # Registers a prefix
    ##
    def add_prefix(ns, uri)
      @prefixes[ns] = uri
    end
    
    ##
    # Registers a variable
    ##
    def add_variable(name)
      @variables[name] ||= RDF::Query::Variable.new(name)
    end

    ##
    # Registers a target
    ##
    def add_target(var)
      @targets << var
    end
    
    ##
    # Returns a match array
    ##
    def match(pattern)
      if (@line =~ pattern) == 0
        @line = $'.lstrip
        Regexp.last_match.to_a
      end
    end
    
  end
end
