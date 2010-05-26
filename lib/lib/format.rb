module RDF::SPARQL

  class Format < RDF::Format
    content_type     'application/sparql', :extension => :sparql
    content_encoding 'utf-8'

    reader { RDF::SPARQL::Reader }
    writer { RDF::SPARQL::Writer }

  end
end
