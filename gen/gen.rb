#!/usr/bin/env ruby

require 'erubis'
require 'multi_json'

unless ARGV.size == 1
  puts "usage: ./gen.rb (modelname)"
  exit(1)
end

modelname = ARGV[0]

RESOURCE_TEMPLATE = <<-RESOURCE_TEMPLATE
// WARNING: generated code from heroku/heroics

package heroku

import (
	"time"
)

// <%= definition['description'] %>
type <%= resource_class %> struct {
<%- definition['properties'].each do |propname, val| %>
  <%- if val.keys.include?("$ref") %>
  // <%= definition['definitions'][propname]["description"] %>
  <%- else %>
  // <%= val["description"] %>
  <%- end %>
  <%= titlecase(propname) %> <%= type_for_prop(definition, propname) %> `json:"<%= propname %>"`

<%- end %>
}

<%- definition["links"].each do |link| %>
  <%- func_name = titlecase(key.downcase. + "-" + link["title"]) %>
  <%- func_args = [] %>
  <%- func_args << (variablecase(parent_resource_instance) + 'Identity string') if parent_resource_instance %>
  <%- func_args += func_args_from_model_and_link(definition, key, link) %>
  <%- return_values = returnvals(titlecase(key), link["rel"]) %>
  <%- path = link['href'].gsub("{(%2Fschema%2F\#{key}%23%2Fdefinitions%2Fidentity)}", '"+' + variablecase(resource_instance) + 'Identity') %>
  <%- if parent_resource_instance %>
    <%- path = path.gsub("{(%2Fschema%2F" + parent_resource_instance + "%23%2Fdefinitions%2Fidentity)}", '" + ' + variablecase(parent_resource_instance) + 'Identity + "') %>
  <%- end %>
  <%- path = ensure_balanced_end_quote(ensure_open_quote(path)) %>

  // <%= link["description"] %>
  <%- func_arg_comments = [] %>
  <%- func_arg_comments << (variablecase(parent_resource_instance) + "Identity is the unique identifier of the " + key + "'s " + parent_resource_instance + ".") if parent_resource_instance %>
  <%- func_arg_comments += func_arg_comments_from_model_and_link(definition, key, link) %>
  //
  <%- word_wrap(func_arg_comments.join(" "), line_width: 77).split("\n").each do |comment| %>
    // <%= comment %>
  <%- end %>
  <%- required = (link["schema"] && link["schema"]["required"]) || [] %>
  <%- optional = ((link["schema"] && link["schema"]["properties"]) || {}).keys - required %>
  <%- postval = !required.empty? ? "params" : "options" %>
  func (c *Client) <%= func_name + "(" + func_args.join(', ') %>) <%= return_values %> {
    <%- case link["rel"] %>
    <%- when "create" %>
      var <%= variablecase(key) %> <%= titlecase(key) %>
      return &<%= variablecase(key) %>, c.Post(&<%= variablecase(key) %>, <%= path %>, <%= postval %>)
    <%- when "self" %>
      var <%= variablecase(key) %> <%= titlecase(key) %>
      return &<%= variablecase(key) %>, c.Get(&<%= variablecase(key) %>, <%= path %>)
    <%- when "destroy" %>
      return c.Delete(<%= path %>)
    <%- when "update" %>
      <%- if !required.empty? %>
        params := struct {
        <%- required.each do |propname| %>
          <%= titlecase(propname) %> <%= type_for_prop(definition, propname) %> `json:"<%= propname %>"`
        <%- end %>
        }{
        <%- required.each do |propname| %>
          <%= titlecase(propname) %>: <%= variablecase(propname) %>,
        <%- end %>
        }
      <%- end %>
      var <%= variablecase(key) %> <%= titlecase(key) %>
      return &<%= variablecase(key) %>, c.Patch(&<%= variablecase(key) %>, <%= path %>, <%= postval %>)
    <%- when "instances" %>
      req, err := c.NewRequest("GET", <%= path %>, nil)
      if err != nil {
        return nil, err
      }

      if lr != nil {
        lr.SetHeader(req)
      }

      var <%= variablecase(key) %>s []<%= titlecase(key) %>
      return <%= variablecase(key) %>s, c.DoReq(req, &<%= variablecase(key) %>s)
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
          <%- else %>
            // <%= definition["definitions"][propname]["description"] %>
          <%- end %>
          <%= titlecase(propname) %> <%= type_for_link_opts_field(definition, link, propname) %> `json:"<%= propname %>,omitempty"`
        <%- end %>
      }
    <%- end %>
  <%- end %>

<%- end %>
RESOURCE_TEMPLATE

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

def variablecase(str)
  words = str.gsub('_','-').gsub(' ','-').split('-')
  (words[0...1] + words[1..-1].map {|k| k[0...1].upcase + k[1..-1]}).join
end

def titlecase(str)
  str.gsub('_','-').gsub(' ','-').split('-').map {|k| k[0...1].upcase + k[1..-1]}.join
end

def type_for_link_opts_field(definition, link, propname, nullable = true)
  inline_object = false
  typedef = if definition["definitions"][propname]
              inline_object = true
              definition["definitions"][propname]
            else definition["properties"][propname]
              definition['properties'][propname]
            end

  tname = ""

  if inline_object
    types = typedef["type"]
    types.delete("null")
    tname = case types.first
            when "boolean"
              "bool"
            when "integer"
              "int"
            when "string"
              format = typedef["format"]
              format && format == "date-time" ? "time.Time" : "string"
            when "object"
              "map[string]string"
            else
              types.first
            end
  else
    tname = "string"
  end
  nullable ? "*#{tname}" : tname
end

def type_for_prop(definition, propname)
  nullable = false
  tname = ""
  if definition["properties"][propname] && definition["properties"][propname].keys.include?("$ref")
    types = definition["definitions"][propname]["type"]
    nullable = true if types.delete("null")
    tname = type_from_types_and_format(types, definition["definitions"][propname]["format"])
  elsif definition["definitions"][propname]
    types = definition["definitions"][propname]["type"]
    tname = type_from_types_and_format(types, definition["definitions"][propname]["format"])
  else
    tname = definition["properties"][propname]["properties"].first[1]["$ref"].match(/\/schema\/(\w+)#/)[1]
    tname = titlecase(tname)
  end
  "#{'*' if nullable}#{tname}"
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

def returnvals(resclass, relname)
  case relname
  when "destroy"
    "error"
  when "instances"
    "([]#{resclass}, error)"
  else
    "(*#{resclass}, error)"
  end
end

def func_args_from_model_and_link(definition, modelname, link)
  args = []
  required = (link["schema"] && link["schema"]["required"]) || []
  optional = ((link["schema"] && link["schema"]["properties"]) || {}).keys - required

  if %w{update destroy self}.include?(link["rel"])
    args << "#{variablecase(modelname)}Identity string"
  end

  if %w{create update}.include?(link["rel"])
    required.each do |propname|
      args << "#{variablecase(propname)} #{type_for_link_opts_field(definition, link, propname, false)}"
    end
    args << "options #{titlecase(modelname)}#{link["rel"].capitalize}Opts" unless optional.empty?
  end

  if "instances" == link["rel"]
    args << "lr *ListRange"
  end

  args
end

def func_arg_comments_from_model_and_link(definition, modelname, link)
  # TODO: update to document all required params
  args = []
  required = (link["schema"] && link["schema"]["required"]) || []
  optional = ((link["schema"] && link["schema"]["properties"]) || {}).keys - required

  if %w{update destroy self}.include?(link["rel"])
    args << "#{variablecase(modelname)}Identity is the unique identifier of the #{titlecase(modelname)}."
  end

  if %w{create update}.include?(link["rel"])
    required.each do |propname|
      desckey = "definitions"
      if definition['properties'][propname] && definition['properties'][propname]['description']
        desckey = "properties"
      end
      args << "#{variablecase(propname)} is the #{must_end_with(definition[desckey][propname]["description"], ".")}"
    end
    args << "options is the struct of optional parameters for this call." unless optional.empty?
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

schema_path = File.expand_path("./schema/#{modelname}.json")
data = MultiJson.load(File.read(schema_path))

if data['links'].empty?
  puts "no links"
  exit(1)
end

resource_class = titlecase(modelname)
resource_instance = resource_instance_from_model(modelname)

resource_proxy_class = resource_class + 's'
resource_proxy_instance = resource_instance + 's'

parent_resource_class, parent_resource_identity, parent_resource_instance = if data['links'].all? {|link| link['href'].include?('{(%2Fschema%2Fapp%23%2Fdefinitions%2Fidentity)}')}
  ['App', 'app_identity', 'app']
end

data = Erubis::Eruby.new(RESOURCE_TEMPLATE).result({
  definition:               data,
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
