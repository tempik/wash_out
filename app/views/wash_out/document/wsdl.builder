xml.instruct!
xml.definitions 'xmlns' => 'http://schemas.xmlsoap.org/wsdl/',
                'xmlns:tns' => @namespace,
                'xmlns:soap' => 'http://schemas.xmlsoap.org/wsdl/soap/',
                'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                'xmlns:soap-enc' => 'http://schemas.xmlsoap.org/soap/encoding/',
                'xmlns:wsdl' => 'http://schemas.xmlsoap.org/wsdl/',
                'name' => @name,
                'targetNamespace' => @namespace do

  xml.types do
    xml.tag! "xsd:schema", :targetNamespace => @namespace do
      defined = []
      @map.each do |operation, formats|
        next unless operation_allowed? operation #t

        (formats[:in] + formats[:out]).each do |p|
          wsdl_type xml, p, defined
        end
         wsdl_message_element wsdl_operation_request_element_name(operation), formats[:in], xml, p, defined
         wsdl_message_element wsdl_operation_response_element_name(operation), formats[:out], xml, p, defined
      end
    end
  end

  xml.portType :name => "#{@name}_port" do
    @map.each do |operation, formats|
      next unless operation_allowed? operation #t
      xml.operation :name => operation do
        xml.input :message => "tns:#{operation}"
        xml.output :message => "tns:#{formats[:response_tag]}"
      end
    end
  end

  xml.binding :name => "#{@name}_binding", :type => "tns:#{@name}_port" do
    xml.tag! "soap:binding", :style => 'document', :transport => 'http://schemas.xmlsoap.org/soap/http'
    @map.keys.each do |operation|
      next unless operation_allowed? operation #t
      xml.operation :name => operation do
        xml.tag! "soap:operation", :soapAction => operation, :style => :document
        xml.input do
          xml.tag! "soap:body",
            :use => "literal"#,:namespace => @namespace
        end
        xml.output do
          xml.tag! "soap:body",
            :use => "literal"#,:namespace => @namespace
        end
      end
    end
  end

  xml.service :name => "service" do
    xml.port :name => "#{@name}_port", :binding => "tns:#{@name}_binding" do
      xml.tag! "soap:address", :location => send("#{@name}_action_url")
    end
  end

  @map.each do |operation, formats|
    next unless operation_allowed? operation #t
    xml.message :name => "#{operation}" do
      formats[:in].each do |p|
        xml.part wsdl_occurence(p, false, :name => p.name, :element => "tns:#{wsdl_operation_request_element_name(operation)}")
      end
    end
    xml.message :name => formats[:response_tag] do
      formats[:out].each do |p|
        xml.part wsdl_occurence(p, false, :name => p.name, :element => "tns:#{wsdl_operation_response_element_name(operation)}")
      end
    end
  end
end
