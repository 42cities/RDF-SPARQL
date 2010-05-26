module RDF::SPARQL
  class Writer < RDF::Writer
    
    include RDF::SPARQL::Common
    format RDF::SPARQL::Format

    ##
    # @param  [IO, File] output
    # @yield  [writer]
    # @yieldparam [Writer] writer
    ##
    def initialize(output = $stdout, options = {}, &block)
      @output, @options = output, options
      @graph = RDF::Graph.new
      @targets = []
      if block_given?
        block.call(self)
        write_query
      end
    end
    
    
    ##
    # Stores the SPARQL representation of a triple.
    #
    # @param  [RDF::Resource] subject
    # @param  [RDF::URI]      predicate
    # @param  [RDF::Value]    object
    # @return [void]
    ##
    def write_triple(subject, predicate, object)
      @graph << RDF::Query::Pattern.new(subject, predicate, object)
    end
    
    ##
    # @param  [Array<Array(Value)>] triples
    def write_triples(triples)
      triples.each { |triple| write_triple(*triple) }
    end
    
    ##
    # [-]
    ##
    def new_target(name_or_uri = nil)
      @targets << case name_or_uri
        when String     then RDF::Query::Variable.new(name_or_uri)
        when RDF::URI   then name_or_uri
        else            RDF::Query::Variable.new('v%s' % rand(10000))
      end
      @targets.last
    end
    
    ##
    # [-]
    ##
    def write_query
      puts format_prologue
      puts format_where
      puts write_epilogue
    end

    private
    
    ##
    # [-]
    ##
    def format_prologue
      format_prefix
      case type
        when :select    then write_select_target
        when :describe  then write_describe_target
        when :construct then write_construct_target
        when :ask       then write_ask_target
      end
    end
    
    ##
    # [-]
    ##
    def format_prefix
      ""
    end
    
    ##
    # [-]
    ##
    def write_select_target
      "SELECT %s %s %s \n" % [
        distinct? ? "DISTINCT" : "",
        reduced? ? "REDUCED" : "",
        write_targets ]
    end
    
    ##
    # [-]
    ##
    def write_describe_target
      "DESCRIBE %s \n" % [
        write_targets ]
    end
    
    ##
    # [-]
    ##
    def write_construct_target
      raise NotImplementedError, '`CONSTRUCT` queries are not yet supported'
    end
    
    ##
    # [-]
    ##
    def write_ask_target
      raise NotImplementedError, '`ASK` queries are not yet supported'
    end
    
    ##
    # [-]
    ##
    def write_targets
      @targets.map { |target| format_value(target) }.join(' ')
    end
    
    ##
    # [-]
    ##
    def format_where
      "WHERE { %s %s }" % [
        triples.map { |triple| format_triple(*triple) }.join("\n"),
        variables.map { |variable| format_filter(variable) }.join("\n") ]
    end
        
    ##
    # [-]
    ##
    def write_epilogue(options = {})
      ""
    end

    ##
    # Returns the SPARQL representation of a statement.
    #
    # @param  [RDF::Statement] statement
    # @return [String]
    ##
    def format_statement(statement)
      format_triple(*statement.to_triple)
    end

    ##
    # Returns the SPARQL representation of a triple.
    #
    # @param  [RDF::Resource] subject
    # @param  [RDF::URI]      predicate
    # @param  [RDF::Value]    object
    # @return [String]
    ##
    def format_triple(subject, predicate, object)
      "%s %s %s ." % [subject, predicate, object].map { |value| format_value(value) }
    end

    ##
    # Returns the SPARQL representation of a URI reference.
    #
    # @param  [RDF::URI] literal
    # @param  [Hash{Symbol => Object}] options
    # @return [String]
    ##
    def format_uri(uri, options = {})
      "<%s>" % uri_for(uri)
    end

    ##
    # Returns the SPARQL representation of a blank node.
    #
    # @param  [RDF::Node] node
    # @param  [Hash{Symbol => Object}] options
    # @return [String]
    ##
    def format_node(node, options = {})
      "_:%s" % node.id
    end
    
    ##
    # Returns the SPARQL representation of a variable.
    #
    # @param  [RDF::Variable] node
    # @param  [Hash{Symbol => Object}] options
    # @return [String]
    ##
    def format_variable(variable, options = {})
      if variable.literal?
        '"%s"' % variable.value
      else
        "?%s" % variable.name
      end
    end
    
    ##
    # Returns the N-Triples representation of a blank node.
    #
    # @param  [RDF::Node] node
    # @param  [Hash{Symbol => Object}] options
    # @return [String]
    ##
    def format_filter(variable, options = {})
#      "FILTER(%s %s %s)" % [format_variable(variable), variable.comparison, variable.value]
      ""
    end
    
    ##
    # @param  [Value] value
    # @return [String]
    ##
    def format_value(value, options = {})
      case value
        when String
          format_literal(value, options)
        when RDF::Literal
          format_literal(value, options)
        when RDF::URI
          format_uri(value, options)
        when RDF::Node
          format_node(value, options)
        when RDF::Query::Variable
          format_variable(value, options)
        else nil
      end
    end
    
    ##
    # Returns the N-Triples representation of a literal.
    #
    # @param  [RDF::Literal, String, #to_s] literal
    # @param  [Hash{Symbol => Object}] options
    # @return [String]
    ##
    def format_literal(literal, options = {})
      case literal
        when RDF::Literal
          text = quoted(escaped(literal.value))
          text << "@#{literal.language}" if literal.has_language?
          text << "^^<#{uri_for(literal.datatype)}>" if literal.has_datatype?
          text
        else
          quoted(escaped(literal.to_s))
      end
    end
    
  end
end
