#!/usr/bin/env ruby

require 'erubis'
require 'multi_json'


RESOURCE_TEMPLATE = <<-RESOURCE_TEMPLATE
// WARNING: generated code from heroku/heroics

package heroku

<%- if schemas[key]['properties'] && schemas[key]['properties'].any?{|p, v| resolve_typedef(v).end_with?("time.Time") } %>
import (
	"time"
)
<%- end %>

<%- if definition['properties'] %>
  <%- description = markdown_free(definition["description"] || "") %>
  <%- word_wrap(description, line_width: 77).split("\n").each do |line| %>
    // <%= line %>
  <%- end %>
  type <%= resource_class %> struct {
  <%- definition['properties'].each do |propname, propdef| %>
    <%- resolved_propdef = resolve_propdef(propdef) %>
    // <%= resolved_propdef["description"] %>
    <%- type = resolve_typedef(resolved_propdef) %>
    <%- if type =~ /\\*?struct/ %>
      <%= titlecase(propname) %> <%= type %> {
        <%- resolved_propdef["properties"].each do |subpropname, subpropdef| %>
          <%= titlecase(subpropname) %> <%= resolve_typedef(subpropdef) %> `json:"<%= subpropname %>"`
        <%- end %>
      } `json:"<%= propname %>"`
    <%- else %>
      <%= titlecase(propname) %> <%= resolve_typedef(propdef) %> `json:"<%= propname %>"`
    <%- end %>

  <%- end %>
  }
<%- end %>

<%- definition["links"].each do |link| %>
  <%- func_name = titlecase(key.downcase. + "-" + link["title"]) %>
  <%- func_args = [] %>
  <%- func_args << (variablecase(parent_resource_instance) + 'Identity string') if parent_resource_instance %>
  <%- func_args += func_args_from_model_and_link(definition, key, link) %>
  <%- return_values = returnvals(key, link["rel"]) %>
  <%- path = link['href'].gsub("{(%2Fschema%2F\#{key}%23%2Fdefinitions%2Fidentity)}", '"+' + variablecase(resource_instance) + 'Identity') %>
  <%- if parent_resource_instance %>
    <%- path = path.gsub("{(%2Fschema%2F" + parent_resource_instance + "%23%2Fdefinitions%2Fidentity)}", '" + ' + variablecase(parent_resource_instance) + 'Identity + "') %>
  <%- end %>
  <%- path = ensure_balanced_end_quote(ensure_open_quote(path)) %>

  <%- word_wrap(link["description"], line_width: 77).split("\n").each do |line| %>
    // <%= line %>
  <%- end %>
  <%- func_arg_comments = [] %>
  <%- func_arg_comments << (variablecase(parent_resource_instance) + "Identity is the unique identifier of the " + key + "'s " + parent_resource_instance + ".") if parent_resource_instance %>
  <%- func_arg_comments += func_arg_comments_from_model_and_link(definition, key, link) %>
  //
  <%- word_wrap(func_arg_comments.join(" "), line_width: 77).split("\n").each do |comment| %>
    // <%= comment %>
  <%- end %>
  <%- required = (link["schema"] && link["schema"]["required"]) || [] %>
  <%- optional = ((link["schema"] && link["schema"]["properties"]) || {}).keys - required %>
  <%- postval = if required.empty? && optional.empty? %>
    <%-           "nil" %>
    <%-         elsif required.empty? %>
    <%-           "options" %>
    <%-         else %>
    <%-           "params" %>
    <%-         end %>
  <%- hasCustomType = !schemas[key]["properties"].nil? %>
  func (c *Client) <%= func_name + "(" + func_args.join(', ') %>) <%= return_values %> {
    <%- case link["rel"] %>
    <%- when "create" %>
      <%- if !required.empty? %>
        <%= Erubis::Eruby.new(LINK_PARAMS_TEMPLATE).result({link: link, required: required, optional: optional}).strip %>
      <%- end %>
      var <%= variablecase(key + '-res') %> <%= titlecase(key) %>
      return &<%= variablecase(key + '-res') %>, c.Post(&<%= variablecase(key + '-res') %>, <%= path %>, <%= postval %>)
    <%- when "self" %>
      var <%= variablecase(key) %> <%= hasCustomType ? titlecase(key) : "map[string]string" %>
      return <%= "&" if hasCustomType%><%= variablecase(key) %>, c.Get(&<%= variablecase(key) %>, <%= path %>)
    <%- when "destroy" %>
      return c.Delete(<%= path %>)
    <%- when "update" %>
      <%- if !required.empty? %>
        <%= Erubis::Eruby.new(LINK_PARAMS_TEMPLATE).result({link: link, required: required, optional: optional}).strip %>
      <%- end %>
      var <%= variablecase(key + '-res') %> <%= hasCustomType ? titlecase(key) : "map[string]string" %>
      return <%= "&" if hasCustomType%><%= variablecase(key + '-res') %>, c.Patch(&<%= variablecase(key + '-res') %>, <%= path %>, <%= postval %>)
    <%- when "instances" %>
      req, err := c.NewRequest("GET", <%= path %>, nil)
      if err != nil {
        return nil, err
      }

      if lr != nil {
        lr.SetHeader(req)
      }

      var <%= variablecase(key + 's-res') %> []<%= titlecase(key) %>
      return <%= variablecase(key + 's-res') %>, c.DoReq(req, &<%= variablecase(key + 's-res') %>)
    <%- end %>
  }

  <%- if %w{create update}.include?(link["rel"]) && link["schema"] && link["schema"]["properties"] %>
    <%- optional_props = link["schema"]["properties"].keys - (link["schema"]["required"] || []) %>
    <%- if !optional_props.empty? %>
      // <%= func_name %>Opts holds the optional parameters for <%= func_name %>
      type <%= func_name %>Opts struct {
        <%- optional_props.each do |propname| %>
          <%- if definition['properties'][propname] && definition['properties'][propname]['description'] %>
            // <%= definition['properties'][propname]['description'] %>
          <%- elsif definition["definitions"][propname] %>
            // <%= definition["definitions"][propname]["description"] %>
          <%- else %>
            // <%= link["schema"]["properties"][propname]["description"] %>
          <%- end %>
          <%= titlecase(propname) %> <%= type_for_link_opts_field(link, propname) %> `json:"<%= propname %>,omitempty"`
        <%- end %>
      }
    <%- end %>
  <%- end %>

<%- end %>
RESOURCE_TEMPLATE

LINK_PARAMS_TEMPLATE = <<-LINK_PARAMS_TEMPLATE
params := struct {
<%- required.each do |propname| %>
  <%= titlecase(propname) %> <%= resolve_typedef(link["schema"]["properties"][propname]) %> `json:"<%= propname %>"`
<%- end %>
<%- optional.each do |propname| %>
  <%= titlecase(propname) %> <%= type_for_link_opts_field(link, propname) %> `json:"<%= propname %>,omitempty"`
<%- end %>
}{
<%- required.each do |propname| %>
  <%= titlecase(propname) %>: <%= variablecase(propname) %>,
<%- end %>
<%- optional.each do |propname| %>
  <%= titlecase(propname) %>: options.<%= titlecase(propname) %>,
<%- end %>
}
LINK_PARAMS_TEMPLATE

#   definition:               data,
#   key:                      modelname,
#   parent_resource_class:    parent_resource_class,
#   parent_resource_identity: parent_resource_identity,
#   parent_resource_instance: parent_resource_instance,
#   resource_class:           resource_class,
#   resource_instance:        resource_instance,
#   resource_proxy_class:     resource_proxy_class,
#   resource_proxy_instance:  resource_proxy_instance

def ensure_open_quote(str)
  str[0] == '"' ? str : "\"#{str}"
end

def ensure_balanced_end_quote(str)
  (str.count('"') % 2) == 1 ? "#{str}\"" : str
end

def must_end_with(str, ending)
  str.end_with?(ending) ? str : "#{str}#{ending}"
end

def word_wrap(text, options = {})
  line_width = options.fetch(:line_width, 80)

  text.split("\n").collect do |line|
    line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip : line
  end * "\n"
end

def markdown_free(text)
  text.gsub(/\[(?<linktext>[^\]]*)\](?<linkurl>\(.*\))/, '\k<linktext>')
end

def variablecase(str)
  words = str.gsub('_','-').gsub(' ','-').split('-')
  (words[0...1] + words[1..-1].map {|k| k[0...1].upcase + k[1..-1]}).join
end

def titlecase(str)
  str.gsub('_','-').gsub(' ','-').split('-').map do |k|
    if k.downcase == "url" # special case so Url becomes URL
      k.upcase
    elsif k.downcase == "oauth" # special case so Oauth becomes OAuth
      "OAuth"
    else
      k[0...1].upcase + k[1..-1]
    end
  end.join
end

def resolve_typedef(propdef)
  if types = propdef["type"]
    null = types.include?("null")
    tname = case (types - ["null"]).first
            when "boolean"
              "bool"
            when "integer"
              "int"
            when "string"
              format = propdef["format"]
              format && format == "date-time" ? "time.Time" : "string"
            when "object"
              if propdef["additionalProperties"] == false
                "map[string]string"
              else
                "struct"
              end
            when "array"
              arraytype = propdef["items"]["type"]
              "[]#{arraytype}"
            else
              types.first
            end
    null ? "*#{tname}" : tname
  elsif propdef["anyOf"]
    # identity cross-reference, cheat because these are always strings atm
    "string"
  elsif propdef["additionalProperties"] == false
    # inline object
    propdef
  elsif ref = propdef["$ref"]
    matches = ref.match(/\/schema\/([\w-]+)#\/definitions\/([\w-]+)/)
    schemaname, fieldname = matches[1..2]
    resolve_typedef(schemas[schemaname]["definitions"][fieldname])
  else
    raise "WTF #{propdef}"
  end
end

def type_for_link_opts_field(link, propname, nullable = true)
  resulttype = resolve_typedef(link["schema"]["properties"][propname])
  if nullable && !resulttype.start_with?("*")
    resulttype = "*#{resulttype}"
  elsif !nullable
    resulttype = resulttype.gsub("*", "")
  end
  resulttype
end

def type_from_types_and_format(types, format)
  case types.first
  when "boolean"
    "bool"
  when "integer"
    "int"
  when "string"
    format && format == "date-time" ? "time.Time" : "string"
  else
    types.first
  end
end

def returnvals(modelname, relname)
  if !schemas[modelname]["properties"]
    # structless type like ConfigVar
    "(map[string]string, error)"
  else
    case relname
    when "destroy"
      "error"
    when "instances"
      "([]#{titlecase(modelname)}, error)"
    else
      "(*#{titlecase(modelname)}, error)"
    end
  end
end

def func_args_from_model_and_link(definition, modelname, link)
  args = []
  required = (link["schema"] && link["schema"]["required"]) || []
  optional = ((link["schema"] && link["schema"]["properties"]) || {}).keys - required

  # check if this link's href requires the model's identity
  match = link["href"].match(%r{%2Fschema%2F#{modelname}%23%2Fdefinitions%2Fidentity})
  if %w{update destroy self}.include?(link["rel"]) && match
    args << "#{variablecase(modelname)}Identity string"
  end

  if %w{create update}.include?(link["rel"])
    if link["schema"]["additionalProperties"] == false
      # handle ConfigVar update
      args << "options map[string]*string"
    else
      required.each do |propname|
        args << "#{variablecase(propname)} #{type_for_link_opts_field(link, propname, false)}"
      end
    end
    args << "options #{titlecase(modelname)}#{link["rel"].capitalize}Opts" unless optional.empty?
  end

  if "instances" == link["rel"]
    args << "lr *ListRange"
  end

  args
end

def resolve_propdef(propdef)
  resolve_all_propdefs(propdef).first
end

def resolve_all_propdefs(propdef)
  if propdef["description"]
    [propdef]
  elsif ref = propdef["$ref"]
    matches = ref.match(/\/schema\/([\w-]+)#\/definitions\/([\w-]+)/)
    schemaname, fieldname = matches[1..2]
    resolve_all_propdefs(schemas[schemaname]["definitions"][fieldname])
  elsif anyof = propdef["anyOf"]
    # Identity
    anyof.map do |refhash|
      matches = refhash["$ref"].match(/\/schema\/([\w-]+)#\/definitions\/([\w-]+)/)
      schemaname, fieldname = matches[1..2]
      resolve_all_propdefs(schemas[schemaname]["definitions"][fieldname])
    end.flatten
  elsif propdef["type"] && propdef["type"].is_a?(Array) && propdef["type"].first == "object"
    # special case for params which are nested objects, like oauth-grant
    [propdef]
  else
    raise "WTF #{propdef}"
  end
end

def func_arg_comments_from_model_and_link(definition, modelname, link)
  args = []
  properties = (link["schema"] && link["schema"]["properties"]) || {}
  required_keys = (link["schema"] && link["schema"]["required"]) || []
  optional_keys = properties.keys - required_keys

  if %w{update destroy self}.include?(link["rel"])
    args << "#{variablecase(modelname)}Identity is the unique identifier of the #{titlecase(modelname)}."
  end

  if %w{create update}.include?(link["rel"])
    required_keys.each do |propname|
      rpresults = resolve_all_propdefs(link["schema"]["properties"][propname])
      if rpresults.size == 1
        args << "#{variablecase(propname)} is the #{must_end_with(rpresults.first["description"] || "", ".")}"
      elsif rpresults.size == 2
        args << "#{variablecase(propname)} is the #{rpresults.first["description"]} or #{must_end_with(rpresults.last["description"] || "", ".")}"
      else
        raise "Didn't expect 3 rpresults"
      end
    end
    args << "options is the struct of optional parameters for this call." unless optional_keys.empty?
  end

  if "instances" == link["rel"]
    args << "lr is an optional ListRange that sets the Range options for the paginated list of results."
  end

  case link["rel"]
  when "create"
    ["options is the struct of optional parameters for this call."]
  when "update"
    ["#{variablecase(modelname)}Identity is the unique identifier of the #{titlecase(modelname)}.",
     "options is the struct of optional parameters for this call."]
  when "destroy", "self"
    ["#{variablecase(modelname)}Identity is the unique identifier of the #{titlecase(modelname)}."]
  when "instances"
    ["lr is an optional ListRange that sets the Range options for the paginated list of results."]
  else
    []
  end
  args
end

def resource_instance_from_model(modelname)
  modelname.downcase.split('-').join('_')
end

def schemas
  @@schemas ||= {}
end

def load_model_schema(modelname)
  schema_path = File.expand_path("./schema/#{modelname}.json")
  schemas[modelname] = MultiJson.load(File.read(schema_path))
end

def generate_model(modelname)
  if !schemas[modelname]
    puts "no schema for #{modelname}" && return
  end
  if schemas[modelname]['links'].empty?
    puts "no links for #{modelname}"
  end

  resource_class = titlecase(modelname)
  resource_instance = resource_instance_from_model(modelname)

  resource_proxy_class = resource_class + 's'
  resource_proxy_instance = resource_instance + 's'

  parent_resource_class, parent_resource_identity, parent_resource_instance = if schemas[modelname]['links'].all? {|link| link['href'].include?('{(%2Fschema%2Fapp%23%2Fdefinitions%2Fidentity)}')}
    ['App', 'app_identity', 'app']
  end

  data = Erubis::Eruby.new(RESOURCE_TEMPLATE).result({
    definition:               schemas[modelname],
    key:                      modelname,
    parent_resource_class:    parent_resource_class,
    parent_resource_identity: parent_resource_identity,
    parent_resource_instance: parent_resource_instance,
    resource_class:           resource_class,
    resource_instance:        resource_instance,
    resource_proxy_class:     resource_proxy_class,
    resource_proxy_instance:  resource_proxy_instance
  })

  path = File.expand_path(File.join(File.dirname(__FILE__), 'output', "#{modelname.gsub('-', '_')}.go"))
  File.open(path, 'w') do |file|
    file.write(data)
  end
  %x( go fmt #{path} )
end

models = Dir.glob("schema/*.json").map{|f| f.gsub(".json", "") }.map{|f| f.gsub("schema/", "")}

models.each do |modelname|
  puts "Loading #{modelname}..."
  load_model_schema(modelname)
end

models.each do |modelname|
  puts "Generating #{modelname}..."
  generate_model(modelname)
end
