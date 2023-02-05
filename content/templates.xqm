xquery version "3.1";


(:~
 : HTML templating module
 :
 : @author Wolfgang Meier
 : @contributor Adam Retter
 : @contributor Joe Wicentowski
 : @contributor Juri Leino
:)
module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace inspect="http://exist-db.org/xquery/inspection";
import module namespace map="http://www.w3.org/2005/xpath-functions/map";
import module namespace array="http://www.w3.org/2005/xpath-functions/array";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace session="http://exist-db.org/xquery/session";
import module namespace util="http://exist-db.org/xquery/util";

import module namespace tmpl-util="http://exist-db.org/xquery/html-templating/utility";

(: configuration root key :)
declare variable $templates:CONFIGURATION := "configuration";
(: configuration setting keys :)
declare variable $templates:CONFIG_STOP_ON_ERROR := "stop-on-error";
declare variable $templates:CONFIG_APP_ROOT := "app-root";
declare variable $templates:CONFIG_ROOT := "root";
declare variable $templates:CONFIG_FN_RESOLVER := "fn-resolver";
declare variable $templates:CONFIG_QNAME_RESOLVER := "qname-resolver";
declare variable $templates:CONFIG_PARAM_RESOLVER := "param-resolver";
declare variable $templates:CONFIG_FILTER_ATTRIBUTES := "filter-atributes";
declare variable $templates:CONFIG_USE_CLASS_SYNTAX := "class-lookup";
declare variable $templates:CONFIG_MAX_ARITY := "max-arity";
declare variable $templates:CONFIG_START_DELIMITER := "start-delimiter";
declare variable $templates:CONFIG_END_DELIMITER := "end-delimiter";

declare variable $templates:PLACEHOLDER_CHECK := "placeholder-check";
declare variable $templates:PLACEHOLDER_REPLACE := "placeholder-replace";

declare variable $templates:ATTR_FILTER_FUNCTION := "attribute-filter-function";
declare variable $templates:SEARCH_IN_CLASS := false();

declare variable $templates:NS := "http://exist-db.org/xquery/html-templating";

(: error QNames :)
declare variable $templates:E_CONFIGURATION :=
    xs:QName("templates:ConfigurationError");
declare variable $templates:E_TEMPLATE_NOT_FOUND :=
    xs:QName("templates:TemplateNotFound");
declare variable $templates:E_FN_NOT_FOUND :=
    xs:QName("templates:FunctionNotFound");
declare variable $templates:E_TYPE :=
    xs:QName("templates:TypeError");
declare variable $templates:E_NOT_ENOUGH_ARGS :=
    xs:QName("templates:NotEngoughArguments");
declare variable $templates:E_ILLEGAL_OPTION :=
    xs:QName("templates:illegal-option");
(: unused :)
declare variable $templates:E_PROCESSING :=
    xs:QName("templates:ProcessingError");
declare variable $templates:E_TOO_MANY_ARGS :=
    xs:QName("templates:TooManyArguments");

(: template attribute prefix :)
declare variable $templates:ATTR_DATA_TEMPLATE := "data-template";

(: default max arity :)
declare variable $templates:MAX_ARITY := 8;

(: legacy parameter resolution strategies :)
declare
variable $templates:lookup-param-from-restserver := (
    request:get-parameter(?, ()),
    session:get-attribute#1,
    request:get-attribute#1
);

(: default configuration, this will be merged with the given configuration :)
declare variable $templates:DEFAULT_CONFIG := map {
    $templates:CONFIG_USE_CLASS_SYNTAX: $templates:SEARCH_IN_CLASS,
    $templates:CONFIG_FN_RESOLVER : templates:function-resolver#2,
    $templates:CONFIG_PARAM_RESOLVER : $templates:lookup-param-from-restserver,
    $templates:CONFIG_MAX_ARITY : $templates:MAX_ARITY,
    $templates:CONFIG_FILTER_ATTRIBUTES : false(),
    $templates:CONFIG_START_DELIMITER: '\$\{',
    $templates:CONFIG_END_DELIMITER: '\}',
    $templates:ATTR_FILTER_FUNCTION : templates:all-attributes#1
};

(:~
 : Start processing the provided content. Template functions are looked up by
 : calling the provided function $resolver. The function should take a name as
 : a string and return the corresponding function item. The simplest implemen-
 : tation of this function could look like this:
 :
 : <pre>function($functionName as xs:string, $arity as xs:integer) { function-lookup(xs:QName($functionName), $arity) }</pre>
 :
 : @param $template the template that will be processed
 : @param $resolver a function which takes a name and returns a function with
 :                  that name
 : @param $model    a map which will be passed to all called template
 :                  functions. Use this to pass information between templating
 :                  instructions.
 :)
declare function templates:apply (
    $template as node(),
    $resolver as function(xs:string, xs:integer) as function(*)?,
    $model as map(*)?
) as node()* {
    templates:apply($template, $resolver, $model, ())
};

(:~
 : Start processing the provided content. Template functions are looked up by
 : calling the provided function $resolver. The function should take a name as
 : a string and return the corresponding function item. The simplest implemen-
 : tation of this function could look like this:
 :
 : <pre>function($functionName as xs:string, $arity as xs:integer) { function-lookup(xs:QName($functionName), $arity) }</pre>
 :
 : @param $template the template that will be processed
 : @param $resolver a function which takes a name and returns a function with
 :                  that name
 : @param $model    a map which will be passed to all called template
 :                  functions. Use this to pass information between templating
 :                  instructions.
 : @param $configuration    a map of configuration parameters. For example you
 :                          may provide a 'parameter value resolver' by mapping
 :                          $templates:CONFIG_PARAM_RESOLVER to a function
 :                          whose job it is to provide values for templated
 :                          parameters. The function signature for the
 :                          'parameter value resolver' is
 :                          function(xs:string) as item()*
 :)
declare function templates:apply (
    $template as node(),
    $resolver as function(xs:string, xs:integer) as function(*)?,
    $model as map(*)?,
    $configuration as map(*)?
) as node()* {
    templates:process($template,
        templates:configure($model,
            templates:merge-legacy-config($configuration, $resolver)))
};

(:~
 : Start processing the provided content.
 :
 : @param $template the template that will be processed
 : @param $model a map which will be passed to all called template functions.
 :    Use this to pass information between templating instructions.
 : @param $configuration a map of configuration parameters.
 :)
declare function templates:render (
    $template as node(),
    $model as map(*)?,
    $configuration as map(*)?
) as node()* {
    templates:process($template,
        templates:configure($model, $configuration))
};

(:~
 : Continue template processing on the given set of nodes. Call this function
 : from within other template functions to enable recursive processing of
 : templates.
 :
 : @param $nodes the nodes to process
 : @param $model a map which will be passed to all called template functions.
 :     Use this to pass information between templating instructions.
 :)
declare function templates:process (
    $nodes as node()*, $model as map(*)
) as node()* {
    (: check for configuration and throw if not  :)
    if (not(map:contains($model, $templates:CONFIGURATION))) then
        error($templates:E_CONFIGURATION,
            "Configuration map not found in model.")
    else templates:process-children($nodes, $model)
};

(:-----------------------------------------------------------------------------
 : utility helper functions
 :---------------------------------------------------------------------------:)

(:~
 : resolve a key to its value using all configures paramter resolvers
 : returning the value of the first result
 :)
declare function templates:resolve-key ($model as map(*), $key as xs:string) {
    tmpl-util:first-result(
        $model($templates:CONFIGURATION)($templates:CONFIG_PARAM_RESOLVER),
        $key)
};

declare function templates:get-app-root ($model as map(*)) as xs:string? {
    $model($templates:CONFIGURATION)($templates:CONFIG_APP_ROOT)
};

declare function templates:get-root ($model as map(*)) as xs:string? {
    (
        $model($templates:CONFIGURATION)($templates:CONFIG_ROOT),
        $model($templates:CONFIGURATION)($templates:CONFIG_APP_ROOT)
    )[1]
};

(:~
 : returns true if $test is true and $templates:CONFIG_STOP_ON_ERROR is
 : set to true in the configuration as well
 :)
declare function templates:do-stop (
    $test as xs:boolean, $model as map(*)
) as xs:boolean {
    $test and
    $model($templates:CONFIGURATION)($templates:CONFIG_STOP_ON_ERROR)
};

declare
function templates:expand-from-model (
    $model as map(*), $nested-key as xs:string
) as item()* {
    fold-left(
        tokenize($nested-key, '\?'), $model, templates:model-resolve#2)
};

(:-----------------------------------------------------------------------------
 : Standard templates
 :---------------------------------------------------------------------------:)

(:~
 : Include an HTML fragment from another file as given in parameter $path.
 : The children (if any) of the including element (i.e. the one triggering the
 : templates:include function) are merged into the included content. To define
 : where a child element should be inserted, you must use a @data-target
 : attribute referencing an HTML id which must exist within the included
 : fragment. If @data-target is missing, the element will be discarded.
 :
 : This is a mechanism to inject content from the including element into the
 : included content. For example, if the same menu or toolbar is included into
 : every page of an application, but some pages should have additional options,
 : you can use templates:include with templates:block to define the additional
 : HTML to be inserted in a specific place.
 :)
declare function templates:include (
    $node as node(), $model as map(*), $path as xs:string
) as node()* {
    let $template := templates:resolve-template($path, $model)
    let $empty := empty($template)

    return
        if (templates:do-stop($empty, $model)) then
            error($templates:E_TEMPLATE_NOT_FOUND,
                "include: template not found at " || $path)
        else if ($empty) then (
            comment { "Include not found: " || $path },
            templates:process-children($node/node(), $model)
        )
        else
            templates:process-children(
                templates:expand-blocks($node, $template), $model)
};

declare function templates:each (
    $node as node(), $model as map(*),
    $from as xs:string, $to as xs:string
) as element()* {
    for $item in $model($from)
    return
        element { node-name($node) } {
            templates:filter-attributes($node, $model),
            templates:process-children($node/node(),
                map:put($model, $to, $item))
        }
};

declare function templates:surround (
    $node as node(), $model as map(*),
    $with as xs:string, $at as xs:string?,
    $using as xs:string?, $options as xs:string?
) as node()* {
    let $doc := templates:resolve-template($with, $model)
    let $template := if ($using) then $doc//@id[. = $using]/.. else $doc
    let $empty := empty($template)

    return
        if (templates:do-stop($empty, $model)) then
            error($templates:E_TEMPLATE_NOT_FOUND,
                "surround: template not found at " || $with ||
                " - using " || $using)
        else if ($empty) then (
            comment { "Surround not found: " || $with },
            templates:process-children($node/node(), $model)
        )
        else
            let $model := templates:surround-options($model, $options)
            let $merged := templates:process-surround($content, $node, $at)
            return
                templates:process-children($merged, $model)
};

declare function templates:if-parameter-set (
    $node as node(), $model as map(*),
    $param as xs:string
) as node()* {
    let $values := templates:resolve-key($model, $param)
    return
        if (exists($values) and string-length(string-join($values)) gt 0) then
            templates:process-children($node/node(), $model)
        else
            ()
};

declare function templates:if-parameter-unset (
    $element as element(), $model as map(*),
    $param as xs:string
) as node()* {
    let $values := templates:resolve-key($model, $param)

    return
        if (empty($values) or string-length(string-join($values)) eq 0) then
            templates:process-children($element/node(), $model)
        else
            ()
};

(: NOTE: to be moved to separate module because:
    1) HTTP Attribute is specific to Java Servlets
    2) Limits use to specifics to REST Server and URL Rewrite!
    If desirable for use from REST Server should be implemented
    elsewhere, perhaps in a module that includes the templates module?!?
:)
declare function templates:if-attribute-set (
    $node as node(), $model as map(*),
    $attribute as xs:string
) as node()* {
    if (exists($attribute) and request:get-attribute($attribute)) then
        templates:process-children($node/node(), $model)
    else
        ()
};

declare function templates:if-model-key-equals (
    $node as node(), $model as map(*),
    $key as xs:string, $value as xs:string
) as node()* {
    if ($model($key) = $value) then
        templates:process-children($node/node(), $model)
    else
        ()
};

(:~
 : Evaluates its enclosed block unless the model property $key is set to value
 : $value.
 :)
declare function templates:unless-model-key-equals (
    $node as node(), $model as map(*),
    $key as xs:string, $value as xs:string
) as node()* {
    if (not($model($key) = $value)) then
        templates:process-children($node/node(), $model)
    else
        ()
};

(:~
 : Evaluate the enclosed block if there's a model property $key equal to $value
 :)
declare function templates:if-module-missing (
    $node as node(), $model as map(*),
    $uri as xs:string, $at as xs:string
) {
    try {
        util:import-module($uri, "testmod", $at)
    } catch * {
        (: Module was not found: process content :)
        templates:process-children($node/node(), $model)
    }
};

(:~
 : Processes input and select form controls, setting their value/selection to
 : values found in the request - if present.
 :)
declare function templates:form-control (
    $node as node(), $model as map(*)
) as node()* {
    switch (local-name($node))
        case "form" return templates:form($node, $model)
        case "input" return templates:input($node, $model)
        case "select" return templates:select($node, $model)
        default return $node
};

declare function templates:error-description (
    $node as node(), $model as map(*)
) as element() {
    let $input := templates:resolve-key($model, "org.exist.forward.error")
    return
        element { node-name($node) } {
            $node/@*,
            try {
                parse-xml($input)//message/string()
            } catch * {
                $input
            }
        }
};

(:-----------------------------------------------------------------------------
 : internal helper functions
 :---------------------------------------------------------------------------:)

declare %private
function templates:surround-options (
    $model as map(*), $options as xs:string?
) as map(*) {
    if (empty($options)) then $model
    else
        map:merge((
            templates:parse-options($model, $options),
            $model
        ), map {"duplicates": "use-last"})
};

(:~
 : parse options string
 : comma-separated list of key value pairs
 : example: a, b= 23 ,c =another value
 : ensures configuration cannot be overwritten
 :)
declare %private
function templates:parse-options ($model, $options as xs:string) as map(*)* {
    for $option in tokenize($options, "\s*,\s*")
    let $key-value-pair := tokenize($option, "\s*=\s*")
    let $problematic-key := $key-value-pair[1] = ("", $templates:CONFIGURATION)
    return
        if (templates:do-stop($problematic-key, $model)) then
            error($templates:E_ILLEGAL_OPTION,
                "illegal option '" || $option || "'")
        else if ($problematic-key) then
            ( (:skip empty and forbidden :) )
        else
            map { $key-value-pair[1] : ($key-value-pair[2], true())[1] }
};

declare %private
function templates:process-surround (
    $node as node(), $content as node(),
    $at as xs:string
) as node()* {
    typeswitch ($node)
        case document-node() return
            for $child in $node/node()
            return templates:process-surround($child, $content, $at)
        case element() return
            if ($node/@id eq $at) then
                element { node-name($node) } {
                    $node/@*, $content/node()
                }
            else
                element { node-name($node) } {
                    $node/@*,
                    for $child in $node/node()
                    return templates:process-surround($child, $content, $at)
                }
        default return $node
};

declare %private
function templates:filter-attributes (
    $node as node(), $model as map(*)
) as attribute()* {
    $model($templates:CONFIGURATION)($templates:ATTR_FILTER_FUNCTION)($node)
};

declare %private
function templates:filtered-attributes ($node as node()) as attribute()* {
    $node/@*[not(templates:is-template-attribute(.))]
};

declare %private
function templates:all-attributes ($node as node()) as attribute()* {
    $node/@*
};

declare %private
function templates:is-template-attribute (
    $attribute as attribute()
) as xs:boolean {
    starts-with(
        local-name($attribute),
        $templates:ATTR_DATA_TEMPLATE)
};

declare %private
function templates:form (
    $form as element(form), $model as map(*)
) as element(form) {
    element form {
        $form/@* except $form/@action,
        attribute action {
            templates:resolve-key($model, "form-action")
        },
        for $child-node in $form/node()
        return templates:form-control($child-node, $model)
    }
};

declare %private
function templates:input (
    $node as element(input), $model as map(*)
) as element(input) {
    let $value := templates:resolve-key($model, $node/@name)
    return
        if (empty($value)) then $node
        else
            let $attributes :=
                switch ($node/@type)
                    case "checkbox"
                    case "radio" return (
                        $node/@* except $node/@checked,
                        if ($node/@value = $value or $value = "true")
                        then attribute checked { "checked" }
                        else ()
                    )
                    default return (
                        $node/@* except $node/@value,
                        attribute value { $value }
                    )

            return
                element input {
                    $attributes,
                    $node/node()
                }
};

declare %private
function templates:select (
    $node as element(select), $model as map(*)
) as element(select) {
    let $value := templates:resolve-key($model, $node/@name/string())
    let $options := $node/option
    return
        element select {
            $node/@*,
            if (empty($value)) then $options
            else
                for $option in $options
                let $selected := 
                    if ($option/@value = $value or $option/string() = $value)
                    then attribute selected { "selected" }
                    else ()
                return
                    element option {
                        $option/@* except $option/@selected,
                        $selected,
                        $option/node()
                    }
        }
};

declare %private
function templates:copy-node (
    $node as element(), $model as map(*)
) as element() {
    element { node-name($node) } {
        templates:expand-attributes(
            templates:filtered-attributes($node), $model),
        templates:process-children($node/node(), $model)
    }
};

declare %private
function templates:shallow-copy-node (
    $node as element(), $model as map(*)
) as element() {
    element { node-name($node) } { $node/@* }
};

declare %private
function templates:resolve-template (
    $path as xs:string, $model as map(*)
) as document-node()? {
    let $resolved-path :=
        if (starts-with($path, "/")) then
            (: Search template relative to app root :)
            concat(templates:get-app-root($model), $path)
        else if (matches($path, "^https?://")) then
            (: Template is loaded from a URL, this template even if a HTML
             : file, must be returned with mime-type XML and be valid XML, as
             : it is retrieved with fn:doc() :)
            $path
        else
            (: Locate template relative to HTML file :)
            concat(templates:get-root($model), "/", $path)

    return doc($resolved-path)
};

declare %private
function templates:model-resolve (
    $context as map(*)?, $key as xs:string
) as item()* {
    if (empty($context)) then () else $context($key)
};

declare %private
function templates:expand-attributes (
    $attrs as attribute()*, $model as map(*)
) as attribute()* {
    for $attr in $attrs
    return
        if (templates:has-placeholder($attr, $model))
        then attribute { node-name($attr) } {
            templates:expand-text($attr, $model) }
        else $attr
};

declare %private
function templates:expand-attributes-from-element (
    $element as element(), $model as map(*)
) as element() {
    element { node-name($element) } {
        templates:expand-attributes($element/@*, $model),
        $element/node()
    }
};

declare %private
function templates:has-placeholder ($node as node(), $model as map(*)) as xs:boolean {
    matches($node,
        $model($templates:CONFIGURATION)($templates:PLACEHOLDER_CHECK))
};

declare %private
function templates:expand-text (
    $text as xs:string, $model as map(*)
) as xs:string {
    let $parsed := analyze-string($text, 
        $model($templates:CONFIGURATION)($templates:PLACEHOLDER_REPLACE))
    let $result :=
        for $token in $parsed/node()
        return
            typeswitch($token)
                case element(fn:non-match) return $token/string()
                case element(fn:match) return
                    templates:handle-matches($token, $model)
                default return $token

    return string-join($result)
};

declare %private
function templates:handle-matches (
    $token as element(fn:match), $model as map(*)
) as xs:string* {
    let $key := $token/fn:group[1]/string()
    let $default-value := $token/fn:group[2]/string()
    let $resolvers := (
        $model($templates:CONFIGURATION)($templates:CONFIG_PARAM_RESOLVER),
        templates:expand-from-model($model, ?)
    )

    let $resolved-value := tmpl-util:first-result($resolvers, $key)

    let $values :=
        if (exists($resolved-value))
        then $resolved-value
        else $default-value

    return
        for $value in $values
        return
            typeswitch($value)
                case map(*) | array(*) return
                    serialize($value, map { "method": "json" })
                default return $value
};

(:~
 : Collect the children of the current element into a map, grouped by
 : @data-target.
 : Then call templates:expand-blocks-recursive to replace the corresponding
 : target nodes in the included content with the collected HTML nodes.
 :)
declare %private
function templates:expand-blocks (
    $context as node(), $included as document-node()
) as node()* {
    let $blocks :=
        for $blocks in $context/element()[@data-target]
        group by $name := $blocks/@data-target
        return
            map { $name : $blocks }

    return
        templates:expand-blocks-recursive(
            map:merge($blocks), $included/node())
};

declare %private
function templates:expand-blocks-recursive (
    $blocks as map(*), $nodes as node()*
) as node()* {
    for $node in $nodes
    return
        typeswitch ($node)
            case element() return
                if ($node/@id and map:contains($blocks, $node/@id)) then
                    $blocks($node/@id)
                else
                    element { node-name($node) } {
                        $node/@*,
                        templates:expand-blocks-recursive(
                            $blocks, $node/node())
                    }
            default return
                $node
};

declare %private
function templates:configure (
    $maybe-model as map(*)?,
    $maybe-config as map(*)?
) as map(*) {
    let $model := map:merge(($maybe-model, map {}))

    (: pre-process :)
    let $mapped-config-options :=
        map:for-each(
            $maybe-config, templates:map-configuration-options#2)

    (: merge with defaults :)
    let $with-defaults := map:merge((
        $templates:DEFAULT_CONFIG,
        $mapped-config-options
    ), map {"duplicates": "use-last"})

    (: post-process :)
    let $start := $with-defaults($templates:CONFIG_START_DELIMITER)
    let $end := $with-defaults($templates:CONFIG_END_DELIMITER)

    let $configuration := map:merge((
        $with-defaults,
        map {
            $templates:PLACEHOLDER_REPLACE : $start || "(.+?)(?::(.+?))?" || $end,
            $templates:PLACEHOLDER_CHECK   : $start || ".+?" || $end
        }
    ))

    return
        map:put($model, $templates:CONFIGURATION, $configuration)
};

declare %private
function templates:map-configuration-options (
    $key as xs:anyAtomicType, $value as item()*
) {
    switch ($key)
        case $templates:CONFIG_QNAME_RESOLVER
        return map {
            $templates:CONFIG_FN_RESOLVER : function ($name, $arity) {
                function-lookup($value($name), $arity)
            }
        }
        case $templates:CONFIG_FILTER_ATTRIBUTES
        return map {
            $templates:ATTR_FILTER_FUNCTION :
              if ($value)
              then templates:filtered-attributes#1
              else templates:all-attributes#1
        }

        default return map { $key : $value }
};

declare %private
function templates:merge-legacy-config (
    $maybe-config as map(*)?,
    $maybe-resolver as function(xs:string, xs:integer) as function(*)?
) as map(*)? {
    if (empty($maybe-resolver)) then $maybe-config
    else map:merge((
        $maybe-config,
        map { $templates:CONFIG_FN_RESOLVER : $maybe-resolver }
    ), map {"duplicates": "use-last"})
};

declare %private
function templates:function-resolver (
    $name as xs:string, $arity as xs:integer
) as function(*)? {
    function-lookup(xs:QName($name), $arity)
};

declare %private
function templates:process-children ($nodes as node()*, $model as map(*)) {
    for $node in $nodes
    return
        typeswitch ($node)
            case document-node() return templates:process-children($node/node(), $model)
            case element() return templates:process-element($node, $model)
            case text() return templates:process-text($node, $model)
            default return $node
};

declare %private
function templates:process-text ($node as text(), $model as map(*)) as text() {
    if (templates:has-placeholder($node, $model))
    then text { templates:expand-text($node, $model) }
    else $node
};

(:~
 : Recursively expand template expressions appearing in attributes or text
 : content, trying to expand them from request/session parameters or the
 : current model.
 :
 : Template expressions by default should have the form
 : ${paramName:default text}.
 : You can change the used delimiters from `${` and `}` to something else by
 : overwriting the configuration parameters $start and $end.
 :
 : Specifying a default is optional. If there is no default and the parameter
 : cannot be expanded, the empty string is output.
 :
 : To support navigating the map hierarchy of the model, paramName may be a
 : sequence of map keys separated by ?, i.e. ${address?street} would first
 : retrieve the map property called "address" and then look up the property
 : "street" on it.
 :
 : The templating function should fail gracefully if a parameter or map lookup
 : cannot be resolved, a lookup resolves to multiple items, a map or an array.
 :)
declare %private
function templates:process-element ($node as node(), $model as map(*)) {
    let $config := $model($templates:CONFIGURATION)
    let $tmpl-func := templates:get-template-function($node, $model)
    return
        if (empty($tmpl-func)) then
            (: Templating function not found: just copy the element :)
            templates:copy-node($node, $model)
        else
            templates:expand-attributes-from-element($node, $model)
            => templates:call-by-introspection($model, $config, $tmpl-func)
};

(:~
 : Check if the current $node has a template function attribute declared
 : the obsolete declaration for 'templates:parse-params' is ignored and
 : handled as if no declaration was found.
 :)
declare %private
function templates:get-template-function (
    $node as element(), $model as map(*)
) as function(*)? {
    let $attr := $node/@*[local-name(.) = $templates:ATTR_DATA_TEMPLATE]
    return
        if ($attr eq "templates:parse-params") then (
        ) else if (empty($attr)) then (
            if ($model($templates:CONFIGURATION)($templates:CONFIG_USE_CLASS_SYNTAX) and $node/@class) then (
                util:log("info", ("found qnames in class attribute", tokenize($node/@class, "\s+")[matches(., "^[^:]+:[^:]+")])),
                let $first-qname-match := head(tokenize($node/@class, "\s+")[matches(., "^[^:]+:[^:]+")])
                return if (empty($first-qname-match)) then () else
                    tmpl-util:resolve-fn(
                        $first-qname-match, 
                        $model($templates:CONFIGURATION)($templates:CONFIG_FN_RESOLVER),
                        $model($templates:CONFIGURATION)($templates:CONFIG_MAX_ARITY)
                    )
            ) else ()
        )
        else
            let $f := tmpl-util:resolve-fn($attr/string(), 
                $model($templates:CONFIGURATION)($templates:CONFIG_FN_RESOLVER),
                $model($templates:CONFIGURATION)($templates:CONFIG_MAX_ARITY)
            )
            return
                if (templates:do-stop(empty($f), $model))
                then
                    error($templates:E_FN_NOT_FOUND,
                        "Error Processing node: " || serialize($node) ||
                        " Reason: &#10;" ||
                        "No template function found for call " || $attr ||
                        " (Maximum arity is set to " ||
                        $model($templates:CONFIGURATION)($templates:CONFIG_MAX_ARITY) ||
                        ". You can set a higher maximum arity using " ||
                        "$templates:CONFIG_MAX_ARITY in your configuration.)")
                else $f
};

declare %private
function templates:call-by-introspection (
    $node as element(),
    $model as map(*),
    $config as map(*),
    $fn as function(*)
) {
    let $inspect := inspect:inspect-function($fn)
    let $param-lookup := $config($templates:CONFIG_PARAM_RESOLVER)
    let $parameters := templates:parameters-from-attr($node)
    let $args := templates:map-arguments(
        $inspect/argument, $parameters, $param-lookup)
    let $output := apply($fn, array:join(([ $node, $model ], $args)))

    let $is-wrapping :=
        $inspect/annotation
            [ends-with(@name, ":wrap")]
            [@namespace = $templates:NS]

    return
        if ($is-wrapping) then
            element { node-name($node) } {
                templates:filter-attributes($node, $model),
                templates:process-output($node, $model, $output)
            }
        else
            templates:process-output($node, $model, $output)
};

declare %private
function templates:process-output(
    $node as element(), $model as map(*), $output as item()*
) {
    typeswitch($output)
        case map(*) return
            templates:process-children($node/node(),
                map:merge(($output, $model), map {"duplicates": "use-last"}))
        default return
            $output
};

declare %private
function templates:map-arguments(
    $args as element(argument)*,
    $parameters as map(xs:string, xs:string),
    $param-lookup as function(xs:string) as item()**
) as array(*)* {
    if (count($args) < 2) then error($templates:E_NOT_ENOUGH_ARGS,
        "attempt to call a template function with less than two arguments")
    else if (count($args) = 2) then []
    else
        for $arg in subsequence($args, 3)
        return
            [ templates:map-argument($arg, $parameters, $param-lookup) ]
};

declare %private
function templates:map-argument(
    $arg as element(argument),
    $parameters as map(xs:string, xs:string),
    $param-lookup as function(xs:string) as item()**
) as item()* {
    let $var := $arg/@var/string()
    let $type := $arg/@type/string()

    let $resolvers := (
        $param-lookup,
        $parameters,
        templates:arg-from-annotation(?, $arg)
    )
    let $param := tmpl-util:first-result($resolvers, $var)

    return
        try {
            tmpl-util:cast($param, $type)
        } catch * {
            error($templates:E_TYPE,
                "Failed to cast parameter value '" || $param || "' to the " ||
                "required target type for template function parameter " ||
                "$" || $var || " of function " || ($arg/../@name) || ". " ||
                "Required type was: " || $type || ". " || $err:description)
        }
};

declare %private
function templates:arg-from-annotation (
    $var as xs:string, $arg as element(argument)
) {
    let $anno :=
        $arg/../annotation[ends-with(@name, ":default")]
            [@namespace = $templates:NS]
            [value[1] = $var]

    return tail($anno/value)/string()
};

declare %private
function templates:parameters-from-attr ($node as node()) as map(*) {
    map:merge(
        for $attr in $node/@*[templates:is-template-attribute(.)]
        return templates:parse-attr($attr)
    )
};

declare %private
function templates:parse-attr (
    $attr as attribute()
) as map(xs:string, xs:string) {
    let $key := substring-after(
        local-name($attr), $templates:ATTR_DATA_TEMPLATE || "-")
    let $value := $attr/string()
    return map { $key : $value }
};
