require 'rdf'

module RDF
  module SPARQL
    require 'lib/format'
    require 'lib/extensions/variable'
    autoload :Common, 'lib/common'
    autoload :Reader, 'lib/reader'
    autoload :Writer, 'lib/writer'
    autoload :Version, 'lib/version'
  end
end

