module RDF
  module SPARQL
    module Common

      ##
      # Yields each statement of SPARQL query
      # @yield  [statement]
      # @yieldparam [Statement]
      # @return [Reader]
      ##
      def each_statement(&block)
        @graph.each_statement { |statement| block.call(statement) }
        self
      end

      ##
      # Yields each triple of SPARQL query
      # @yield  [triple]
      # @yieldparam [Array(Value)]
      # @return [Reader]
      ##
      def each_triple(&block)
        @graph.each_triple { |*triple| block.call(*triple) }
        self
      end

      ##
      # Yields each target variable in SPARQL query
      # @yield  [variable]
      # @yieldparam [Variable]
      # @return [Reader]
      ##
      def each_target(&block)
        @targets.each { |target| block.call(target) }
        self
      end

      ##
      # Yields each variable in SPARQL query
      # @yield  [variable]
      # @yieldparam [Variable]
      # @return [Reader]
      ##
      def each_variable(&block)
        variables.each { |variable| block.call(variable) }
        self
      end

      ##
      # [-]
      ##
      def targets
        @targets
      end
      
      ##
      # [-]
      ##
      def statements
        @graph.statements
      end

      ##
      # [-]
      ##
      def triples
        @graph.triples
      end

      ##
      # [-]
      ##
      def variables
        Hash[@graph.map { |pattern|
          pattern.variables.values
        }.flatten.uniq.map { |variable|
          [variable.name, variable]
        }]
      end

      ##
      # [-]
      ##
      def type
        @type || @options[:type]
      end
      
      ##
      # Check whether `distinct` flag was specified
      # @return [Boolean]
      ##
      def distinct?
        @options[:distinct] == true
      end

      ##
      # Check whether `reduced` flag was specified
      # @return [Boolean]
      ##
      def reduced?
        @options[:reduced] == true
      end

    end # Common
  end # SPARQL
end # RDF