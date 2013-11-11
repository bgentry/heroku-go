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
  <%- func_name = titlecase(key.downcase. + "-" + reltranslate(link["rel"])) %>
  <%- func_args = [] %>
  <%- func_args << (parent_resource_instance + 'Identity string') if parent_resource_instance %>
  <%- func_args << func_args_from_model_and_link_rel(key, link["rel"]) %>
  <%- return_values = returnvals(titlecase(key), link["rel"]) %>
  <%- path = link['href'].gsub("{(%2Fschema%2F\#{key}%23%2Fdefinitions%2Fidentity)}", '"+' + resource_instance + 'Identity') %>
  <%- if parent_resource_instance %>
    <%- path = path.gsub("{(%2Fschema%2F" + parent_resource_instance + "%23%2Fdefinitions%2Fidentity)}", '" + ' + parent_resource_instance + 'Identity + "') %>
  <%- end %>
  <%- path = ensure_balanced_end_quote(ensure_open_quote(path)) %>

  // <%= link["description"] %>
  //
  // TODO: add help text for function args
  func (c *Client) <%= func_name + "(" + func_args.compact.join(', ') %>) <%= return_values %> {
    <%- case link["rel"] %>
    <%- when "create" %>
      var <%= key %> <%= titlecase(key) %>
      return &<%= key %>, c.Post(&<%= key %>, <%= path %>, options)
    <%- when "self" %>
      var <%= key %> <%= titlecase(key) %>
      return &<%= key %>, c.Get(&<%= key %>, <%= path %>)
    <%- when "destroy" %>
      return c.Delete(<%= path %>)
    <%- end %>
  }

  <%- if %w{create update}.include?(link["rel"]) && link["schema"] && link["schema"]["properties"] %>
    // <%= func_name %>Opts holds the optional parameters for <%= func_name %>
    type <%= func_name %>Opts struct {
      <%- link["schema"]["properties"].each do |propname, prophash| %>
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

def titlecase(str)
  str.gsub('_','-').split('-').map {|k| k[0...1].upcase + k[1..-1]}.join
end

def type_for_link_opts_field(definition, link, propname)
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
  "*#{tname}"
end

def type_for_prop(definition, propname)
  nullable = false
  tname = ""
  if definition["properties"][propname].keys.include?("$ref")
    types = definition["definitions"][propname]["type"]
    nullable = true if types.delete("null")
    tname = case types.first
            when "boolean"
              "bool"
            when "integer"
              "int"
            when "string"
              format = definition["definitions"][propname]["format"]
              format && format == "date-time" ? "time.Time" : "string"
            else
              types.first
            end
  else
    tname = definition["properties"][propname]["properties"].first[1]["$ref"].match(/\/schema\/(\w+)#/)[1]
    tname = titlecase(tname)
  end
  "#{'*' if nullable}#{tname}"
end

def reltranslate(relname)
  case relname
  when "self"
    "info"
  when "instances"
    "list"
  else
    relname
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

def func_args_from_model_and_link_rel(model, rel)
  case rel
  when "create"
    "options #{titlecase(model)}#{rel.capitalize}Opts"
  when "update"
    "#{model}Identity string, options #{titlecase(model)}#{rel.capitalize}Opts"
  when "destroy", "self"
    model + "Identity string"
  when "instances"
   "lr *ListRange"
  else
    nil
  end
end

def resource_instance_from_model(modelname)
  modelname.downcase.split('-').join('_')
end

schema_path = File.expand_path("./#{modelname}.json")
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

path = File.expand_path(File.join(File.dirname(__FILE__), 'output', "#{modelname}.go"))
File.open(path, 'w') do |file|
  file.write(data)
end
