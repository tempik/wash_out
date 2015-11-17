module WashOutHelper

  def wsdl_data_options(param)
    if controller.soap_config.wsdl_style.class.name =='Symbol'
      controller.soap_config.wsdl_style = controller.soap_config.wsdl_style.to_str
    end
    case controller.soap_config.wsdl_style
    when 'rpc'
      { :"xsi:type" => param.namespaced_type }
    when 'document'
      { }
    end
  end

  def wsdl_data_attrs(param)
    param.map.reduce({}) do |memo, p|
      if p.respond_to?(:attribute?) && p.attribute?
        memo.merge p.attr_name => p.value
      else
        memo
      end
    end
  end


  def wsdl_data_element_wrapper(xml, params)
    schema_namespace = 'xsd'
     xml.tag! "return" do # , :name => name 
      xml.tag! "#{schema_namespace}:complexType" do
        xml.tag! "#{schema_namespace}:sequence" do
          formats.each do |value|
            xml.tag! "#{schema_namespace}:element", wsdl_occurence(value, false, 
             :name => value.name, :type => value.namespaced_type)
          end
        end
      end
    end

  end

  def wsdl_data(xml, params)

    params.each do |param|
      next if param.attribute?
      tag_name = param.name
      param_options = wsdl_data_options(param)
      param_options.merge! wsdl_data_attrs(param)
      tag_name= "tns:#{tag_name}"
      if param.struct?

        if param.multiplied
          param.map.each do |p|
            attrs = wsdl_data_attrs p
            if p.is_a?(Array) || p.map.size > attrs.size
              blk = proc { wsdl_data(xml, p.map) }
            end
            attrs.reject! { |_, v| v.nil? }
            xml.tag! tag_name, param_options.merge(attrs), &blk
          end
        else
          xml.tag! tag_name, param_options do
            wsdl_data(xml, param.map)
          end
        end
      else
        if param.multiplied
          param.value = [] unless param.value.is_a?(Array)
          param.value.each do |v|
            xml.tag! tag_name, v, param_options
          end
        else
          xml.tag! tag_name, param.value, param_options
        end
      end
    end
  end


  def wsdl_operation_response_element_name operation
    "#{operation}ResponseElem"
  end

  def wsdl_operation_request_element_name operation
    "#{operation}RequestElem"
  end


  def wsdl_message_element(name, formats, xml, param, defined=[])
    more = []
    schema_namespace = 'xsd' 

         xml.tag! "#{schema_namespace}:element", :name => name do
          xml.tag! "#{schema_namespace}:complexType" do
            xml.tag! "#{schema_namespace}:sequence" do
              formats.each do |value|
                xml.tag! "#{schema_namespace}:element", wsdl_occurence(value, false, 
                 :name => value.name, :type => value.namespaced_type)
              end
            end
          end
        end
  end



  def wsdl_type(xml, param, defined=[])
    more = []
    schema_namespace = 'xsd' 

    if param.struct?
      if !defined.include?(param.basic_type)
          xml.tag! "#{schema_namespace}:complexType", :name => param.basic_type do
            attrs, elems = [], []
            param.map.each do |value|
              more << value if value.struct?
              if value.attribute?
                attrs << value
              else
                elems << value
              end
            end

            if elems.any?
              xml.tag! "#{schema_namespace}:sequence" do
                elems.each do |value|
                  xml.tag! "#{schema_namespace}:element", wsdl_occurence(value, false, :name => value.name, :type => value.namespaced_type)
                end
              end
            end

            attrs.each do |value|
              xml.tag! "#{schema_namespace}:attribute", wsdl_occurence(value, false, :name => value.attr_name, :type => value.namespaced_type)
            end
          end


        defined << param.basic_type
      elsif !param.classified?
        raise RuntimeError, "Duplicate use of `#{param.basic_type}` type name. Consider using classified types."
      end
    end

    more.each do |p|
      wsdl_type xml, p, defined
    end
  end

  def wsdl_occurence(param, inject, extend_with = {})
    data = !param.multiplied ? {} : {
      "#{'xsi:' if inject}minOccurs" => 0,
      "#{'xsi:' if inject}maxOccurs" => 'unbounded'
    }

    extend_with.merge(data)
  end
end
