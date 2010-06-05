module RDF
  module SPARQL
    module Common
      
      include RDF::Enumerable
      
      ##
      # Yields each statement of SPARQL query.
      # @yield  [statement]
      # @yieldparam [Statement]
      # @return [Reader]
      ##
      def each(&block)
        @graph.each_statement { |statement| block.call(statement) }
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
      # Returns all requested variables.
      # @return [Array<RDF::Query::Variable>]
      ##
      def targets
        @targets.dup
      end
      
      ##
      # Returns all variables.
      # @return [Array<RDF::Query::Variable>]
      ##
      def variables
        @graph.statements.map(&:to_a).flatten.select(&:variable?)
      end

      ##
      # Returns query type (:select, :describe, :ask or :construct).
      # @return [Symbol]
      # @return [nil] if undefined
      ##
      def type
        @type || @options[:type]
      end
      
      ##
      # Returns true if `distinct` flag is specified.
      # @return [Boolean]
      ##
      def distinct?
        @options[:distinct] == true
      end

      ##
      # Returns true if `reduced` flag is specified,
      # @return [Boolean]
      ##
      def reduced?
        @options[:reduced] == true
      end

    end # Common
  end # SPARQL
end # RDF