xquery version "3.1";


(:~
 : HTML templating module
 :
 : @version 2.1
 : @author Wolfgang Meier
 : @contributor Adam Retter
 : @contributor Joe Wicentowski
:)
module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace inspect="http://exist-db.org/xquery/inspection";
import module namespace map="http://www.w3.org/2005/xpath-functions/map";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace session="http://exist-db.org/xquery/session";
import module namespace util="http://exist-db.org/xquery/util";


declare variable $templates:CONFIG_STOP_ON_ERROR := "stop-on-error";
declare variable $templates:CONFIG_APP_ROOT := "app-root";
declare variable $templates:CONFIG_ROOT := "root";
declare variable $templates:CONFIG_FN_RESOLVER := "fn-resolver";
declare variable $templates:CONFIG_PARAM_RESOLVER := "param-resolver";
declare variable $templates:CONFIG_FILTER_ATTRIBUTES := "filter-atributes";
declare variable $templates:CONFIG_USE_CLASS_SYNTAX := "class-lookup";
declare variable $templates:CONFIG_MAX_ARITY := "max-arity";

declare variable $templates:CONFIGURATION := "configuration";

declare variable $templates:NS := "http://exist-db.org/xquery/html-templating";
declare variable $templates:CONFIGURATION_ERROR := xs:QName("templates:ConfigurationError");
declare variable $templates:NOT_FOUND := xs:QName("templates:NotFound");
declare variable $templates:TOO_MANY_ARGS := xs:QName("templates:TooManyArguments");
declare variable $templates:PROCESSING_ERROR := xs:QName("templates:ProcessingError");
declare variable $templates:TYPE_ERROR := xs:QName("templates:TypeError");
declare variable $templates:MAX_ARITY := 8;

declare variable $templates:ATTR_DATA_TEMPLATE := "data-template";
declare variable $templates:SEARCH_IN_CLASS := false();

(:~
 : Start processing the provided content. Template functions are looked up by calling the
 : provided function $resolver. The function should take a name as a string
 : and return the corresponding function item. The simplest implementation of this function could
 : look like this:
 :
 : <pre>function($functionName as xs:string, $arity as xs:integer) { function-lookup(xs:QName($functionName), $arity) }</pre>
 :
 : @param $template the template that will be processed
 : @param $resolver a function which takes a name and returns a function with that name
 : @param $model a map which will be passed to all called template functions. Use this to pass
 : information between templating instructions.
:)
declare function templates:apply(
    $template as node(),
    $resolver as function(xs:string) as xs:QName,
    $model as map(*)?
) {
    templates:apply($template, $resolver, $model, ())
};

(:~
 : Start processing the provided content. Template functions are looked up by calling the
 : provided function $resolver. The function should take a name as a string
 : and return the corresponding function item. The simplest implementation of this function could
 : look like this:
 :
 : <pre>function($functionName as xs:string, $arity as xs:integer) { function-lookup(xs:QName($functionName), $arity) }</pre>
 :
 : @param $template the template that will be processed
 : @param $resolver a function which takes a name and returns a function with that name
 : @param $model a map which will be passed to all called template functions. Use this to pass
 : information between templating instructions.
 : @param $configuration a map of configuration parameters. For example you may provide a
 :  'parameter value resolver' by mapping $templates:CONFIG_PARAM_RESOLVER to a function
 :  whoose job it is to provide values for templated parameters. The function signature for
 :  the 'parameter value resolver' is f($param-name as xs:string) as item()*
:)
declare function templates:apply(
    $template as node(),
    $resolver as function(xs:string) as xs:QName,
    $model as map(*)?,
    $configuration as map(*)?
) {
    templates:process($template,
        map:put(
            map:merge(($model, map {})),
            $templates:CONFIGURATION, 
            map:merge((templates:get-default-config($resolver), $configuration))))
};

declare function templates:render(
    $template as node(),
    $model as map(*)?,
    $configuration as map(*)?
) {
    templates:process($template,
        map:put(
            map:merge(($model, map {})),
            $templates:CONFIGURATION,
            map:merge(($templates:DEFAULT_CONFIG, $configuration))))
};

declare variable $templates:DEFAULT_CONFIG := map {
    $templates:CONFIG_USE_CLASS_SYNTAX: $templates:SEARCH_IN_CLASS,
    $templates:CONFIG_FN_RESOLVER : templates:qname-resolver#1,
    $templates:CONFIG_PARAM_RESOLVER : $templates:lookup-param-from-restserver,
    $templates:CONFIG_MAX_ARITY : $templates:MAX_ARITY
};

declare %private
function templates:qname-resolver ($name as xs:string) as xs:QName { 
    xs:QName($name)
};

declare
    %private
function templates:get-default-config($resolver as function(xs:string) as xs:QName) as map(*) {
    map:put($templates:DEFAULT_CONFIG, $templates:CONFIG_FN_RESOLVER, $resolver)
};

declare function templates:resolve-key($model, $key) {
    let $resolvers := $model($templates:CONFIGURATION)($templates:CONFIG_PARAM_RESOLVER)
    return templates:first-result($resolvers, $key)
};

declare %private
function templates:first-result($fns as function(*)*, $arg) as item()* {
    (: fold-left with no context :)
    (: fold-left($fns, (), function ($res, $next) {
        if (exists($res)) then $res else $next($arg) 
    }) :)

    (: fold-left with dynamic context :)
    fold-left($fns, [$arg, ()], templates:resolve-reducer#2)?2
    
    (: recursion :)
    (: if (empty($fns)) then ()
    else
        let $result := head($fns)($arg)
        return
            if (exists($result)) then $result
            else templates:first-result(tail($fns), $arg) :)
};

declare %private function templates:resolve-reducer ($acc, $next) {
    if (exists($acc?2)) then $acc
    else array:put($acc, 2, $next($acc?1))
};


declare %private
variable $templates:lookup-param-from-restserver := (
    request:get-parameter(?, ()),
    session:get-attribute#1,
    request:get-attribute#1
);

(:~
 : Continue template processing on the given set of nodes. Call this function from
 : within other template functions to enable recursive processing of templates.
 :
 : @param $nodes the nodes to process
 : @param $model a map which will be passed to all called template functions. Use this to pass
 : information between templating instructions.
:)
declare function templates:process($nodes as node()*, $model as map(*)) as node()* {
    (: check for configuration and throw if not  :)
    if (not(map:contains($model, $templates:CONFIGURATION))) then 
        error($templates:CONFIGURATION_ERROR,
            "Configuration map not found in model.")
    else templates:process-children($nodes, $model)
};

declare %private
function templates:process-children($nodes as node()*, $model as map(*)) {
    for $node in $nodes
    return
        typeswitch ($node)
            case document-node() return templates:process-children($node/node(), $model)
            case element() return templates:process-element($node, $model)
            default return $node
};


declare %private
function templates:process-element($node as node(), $model as map(*)) {
    let $config := $model($templates:CONFIGURATION)
    let $tmpl-func := templates:get-template-function($node, $config)
    return
        if (empty($tmpl-func)) then
            (: Templating function not found: just copy the element :)
            templates:copy-node($node, $model)
        else
            templates:call-by-introspection($node, $model, $config, $tmpl-func)
};

declare %private
function templates:get-template-function($node as element(), $config as map(*)) as function(*)? {
    try {
        let $attr := $node/@*[local-name(.) = $templates:ATTR_DATA_TEMPLATE]
        return
            if ($attr)
            then
                templates:resolve($attr/string(), $config)
            else if ($config?($templates:CONFIG_USE_CLASS_SYNTAX) and $node/@class) then (
                util:log("info", ("found qnames in class attribute", tokenize($node/@class, "\s+")[templates:is-qname(.)])),
                let $first-qname-match := head(tokenize($node/@class, "\s+")[templates:is-qname(.)])
                return if (empty($first-qname-match)) then () else templates:resolve($first-qname-match, $config)
            ) else ()
    }
    catch * {
        error($err:code, "Error Processing node: " || serialize($node) || " Reason: &#10;" || $err:description)
    }
};

declare %private function templates:call-by-introspection(
    $node as element(),
    $model as map(*),
    $config as map(*),
    $fn as function(*)
) {
    let $inspect := inspect:inspect-function($fn)
    let $is-wrapping := $inspect/annotation[ends-with(@name, ":wrap")][@namespace = $templates:NS]
    (: let $fn-name := prefix-from-QName(function-name($fn)) || ":" || local-name-from-QName(function-name($fn)) :)
    let $param-lookup := $config($templates:CONFIG_PARAM_RESOLVER)
    let $parameters := templates:parameters-from-attr($node)
    let $args := templates:map-arguments($inspect/argument, $parameters, $param-lookup)
    let $output := apply($fn, array:join(([ $node, $model ], $args)))

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
function templates:process-output($node as element(), $model as map(*), $output as item()*) {
    typeswitch($output)
        case map(*) return
            templates:process-children($node/node(), map:merge(($output, $model)))
        default return
            $output
};

declare %private
function templates:map-arguments(
    $args as element(argument)*,
    $parameters as map(xs:string, xs:string),
    $param-lookup as function(xs:string) as item()**
) as array(*)* {
    if (count($args) < 2) then error((), "attempt to call a template function with less than two arguments")
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
    let $param := templates:first-result($resolvers, $var)

    return
        try {
            templates:cast($param, $type)
        } catch * {
            error($templates:TYPE_ERROR, "Failed to cast parameter value '" || $param || "' to the required target type for " ||
                "template function parameter $" || $var || " of function " || ($arg/../@name) || ". Required type was: " ||
                $type || ". " || $err:description)
        }
};

declare %private
function templates:arg-from-annotation($var as xs:string, $arg as element(argument)) {
    let $anno :=
        $arg/../annotation[ends-with(@name, ":default")]
            [@namespace = $templates:NS]
            [value[1] = $var]
    
    return tail($anno/value)/string()
};

declare %private
function templates:resolve(
    $function-name as xs:string,
    $config as map(*)
) as function(*)? {
    let $f := templates:resolve($function-name, $config, 2)

    return
        if (empty($f) and $config($templates:CONFIG_STOP_ON_ERROR)) 
        then
            error($templates:NOT_FOUND,
                "No template function found for call " || $function-name ||
                " (Max arity of " || $config($templates:CONFIG_MAX_ARITY) ||
                " has been exceeded in searching for this template function." ||
                " If needed, adjust $templates:MAX_ARITY in the templates.xql module.)")
        else $f
};

declare %private
function templates:resolve(
    $function-name as xs:string,
    $config as map(*),
    $arity as xs:integer
) as function(*)? {
    let $qn := $config($templates:CONFIG_FN_RESOLVER)($function-name)
    let $fn := function-lookup($qn, $arity)
    return
        if (exists($fn)) then $fn
        else if ($arity ge $config($templates:CONFIG_MAX_ARITY)) then ()
        else templates:resolve($function-name, $config, $arity + 1)
};

declare %private
function templates:parameters-from-attr($node as node()) as map(*) {
    map:merge(
        for $attr in $node/@*[templates:is-template-attribute(.)]
        return templates:parse-attr($attr)
    )
};

declare %private
function templates:parse-attr($attr as attribute()) as map(xs:string, xs:string) {
    let $key := substring-after(local-name($attr), $templates:ATTR_DATA_TEMPLATE || "-")
    let $value := $attr/string()
    return map { $key : $value }
};

declare %private
function templates:is-qname($class as xs:string) as xs:boolean {
    matches($class, "^[^:]+:[^:]+")
};

declare %private
function templates:cast($values as item()*, $targetType as xs:string) {
    for $value in $values
    return
        if ($targetType != "xs:string" and string-length($value) = 0) then
            (: treat "" as empty sequence :)
            ()
        else
            switch ($targetType)
                case "xs:string" return
                    string($value)
                case "xs:integer" return
                    xs:integer($value)
                case "xs:int" return
                    xs:int($value)
                case "xs:long" return
                    xs:long($value)
                case "xs:decimal" return
                    xs:decimal($value)
                case "xs:float" case "xs:double" return
                    xs:double($value)
                case "xs:date" return
                    xs:date($value)
                case "xs:dateTime" return
                    xs:dateTime($value)
                case "xs:time" return
                    xs:time($value)
                case "xs:boolean" return
                    xs:boolean($value)
                case "element()" return
                    parse-xml($value)/*
                case "text()" return
                    text { string($value) }
                default return
                    $value
};

declare function templates:get-app-root($model as map(*)) as xs:string? {
    $model($templates:CONFIGURATION)($templates:CONFIG_APP_ROOT)
};

declare function templates:get-root($model as map(*)) as xs:string? {
    let $root := $model($templates:CONFIGURATION)($templates:CONFIG_ROOT)
    return
        if ($root) then $root
        else templates:get-app-root($model)
};

(:-----------------------------------------------------------------------------------
 : Standard templates
 :-----------------------------------------------------------------------------------:)

(:~
 : @deprecated use lib:include instead
 :)
declare function templates:include(
    $node as node(), $model as map(*), $path as xs:string
) as node()* {
    let $path :=
        if (starts-with($path, "/")) then
            (: Search template relative to app root :)
            concat(templates:get-app-root($model), "/", $path)
        else if (matches($path, "^https?://")) then
            (: Template is loaded from a URL, this template even if a HTML file, must be
               returned with mime-type XML and be valid XML, as it is retrieved with fn:doc() :)
            $path
        else
            (: Locate template relative to HTML file :)
            concat(templates:get-root($model), "/", $path)
    let $template := doc($path)

    return
        if (empty($template) and $model($templates:CONFIGURATION)($templates:CONFIG_STOP_ON_ERROR)) then
            error($templates:PROCESSING_ERROR, "include: template not found at " || $path)
        else if (empty($template)) then
            templates:process-children($node/node(), $model)
        else
            templates:process-children($template, $model)
};

declare function templates:surround(
    $node as node(), $model as map(*),
    $with as xs:string, $at as xs:string?,
    $using as xs:string?, $options as xs:string?
) as node()* {
    let $appRoot := templates:get-app-root($model)
    let $root := templates:get-root($model)
    let $path :=
        if (starts-with($with, "/")) then
            (: Search template relative to app root :)
            concat($appRoot, $with)
        else if (matches($with, "^https?://")) then
            (: Template is loaded from a URL, this template even if a HTML file, must be
               returned with mime-type XML and be valid XML, as it is retrieved with fn:doc() :)
            $with
        else
            (: Locate template relative to HTML file :)
            concat($root, "/", $with)
    let $content :=
        if ($using) then
            doc($path)//*[@id = $using]
        else
            doc($path)
    return
        if (empty($content)) then
            if ($model($templates:CONFIGURATION)($templates:CONFIG_STOP_ON_ERROR)) then
                error($templates:PROCESSING_ERROR, "surround: template not found at " || $path)
            else
                templates:process-children($node/node(), $model)
        else
            let $model := templates:surround-options($model, $options)
            let $merged := templates:process-surround($content, $node, $at)
            return
                templates:process-children($merged, $model)
};

declare %private
function templates:surround-options($model as map(*), $optionsStr as xs:string?) as map(*) {
    if (empty($optionsStr)) then
        $model
    else
        map:merge((
            $model,
            for $option in tokenize($optionsStr, "\s*,\s*")
            let $keyValue := tokenize($option, "\s*=\s*")
            return
                if (exists($keyValue)) then
                    map:entry($keyValue[1],
                        ($keyValue[2], true())[1])
                else
                    ()
        ))
};

declare %private
function templates:process-surround(
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

declare function templates:each(
    $node as node(), $model as map(*), 
    $from as xs:string, $to as xs:string
) as element()* {
    for $item in $model($from)
    return
        element { node-name($node) } {
            templates:filter-attributes($node, $model),
            templates:process-children($node/node(), map:put($model, $to, $item))
        }
};

declare %private
function templates:filter-attributes($node as node(), $model as map(*)) as attribute()* {
    if ($model($templates:CONFIGURATION)($templates:CONFIG_FILTER_ATTRIBUTES))
    then $node/@*[not(templates:is-template-attribute(.))]
    else $node/@*
};

declare %private
function templates:is-template-attribute($attribute as attribute()) as xs:boolean {
    starts-with(
        local-name($attribute),
        $templates:ATTR_DATA_TEMPLATE)
};

declare function templates:if-parameter-set(
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

declare function templates:if-parameter-unset(
    $node as node(), $model as map(*),
    $param as xs:string
) as node()* {
    let $values := templates:resolve-key($model, $param)

    return
        if (empty($values) or string-length(string-join($values)) eq 0) then
            templates:process-children($node/node(), $model)
        else
            ()
};

(: NOTE: to be moved to separate module because:
    1) HTTP Attribute is specific to Java Servlets
    2) Limits use to specifics to REST Server and URL Rewrite!
    If desirable for use from REST Server should be implemented 
    elsewhere, perhaps in a module that includes the templates module?!?
:)
declare function templates:if-attribute-set(
    $node as node(), $model as map(*),
    $attribute as xs:string
) as node()* {
    if (exists($attribute) and request:get-attribute($attribute)) then
        templates:process-children($node/node(), $model)
    else
        ()
};

declare function templates:if-model-key-equals(
    $node as node(), $model as map(*),
    $key as xs:string, $value as xs:string
) as node()* {
    if ($model($key) = $value) then
        templates:process-children($node/node(), $model)
    else
        ()
};

(:~
 : Evaluates its enclosed block unless the model property $key is set to value $value.
 :)
declare function templates:unless-model-key-equals(
    $node as node(), $model as map(*),
    $key as xs:string, $value as xs:string
) as node()* {
    if (not($model($key) = $value)) then
        templates:process-children($node/node(), $model)
    else
        ()
};

(:~
 : Evaluate the enclosed block if there's a model property $key equal to $value.
 :)
declare function templates:if-module-missing(
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
    Processes input and select form controls, setting their value/selection to
    values found in the request - if present.
 :)
declare function templates:form-control($node as node(), $model as map(*)) as node()* {
    switch (local-name($node))
        case "form" return templates:form($node, $model)
        case "input" return templates:input($node, $model)
        case "select" return templates:select($node, $model)
        default return $node
};

declare function templates:form ($node as element(form), $model as map(*)) as element(form) {
    element { node-name($node) }{
        $node/@* except $node/@action,
        attribute action {
            templates:resolve-key($model, "form-action")
        },
        for $n in $node/node()
        return templates:form-control($n, $model)
    }
};

declare function templates:input ($node as element(input), $model as map(*)) as element(input) {
    let $value := templates:resolve-key($model, $node/@name)
    return
        if (empty($value)) then $node
        else
            switch ($node/@type)
                case "checkbox" 
                case "radio" return
                    element { node-name($node) } {
                        $node/@* except $node/@checked,
                        if ($node/@value = $value or $value = "true") then
                            attribute checked { "checked" }
                        else
                            (),
                        $node/node()
                    }
                default return
                    element { node-name($node) } {
                        $node/@* except $node/@value,
                        attribute value { $value },
                        $node/node()
                    }
};

declare function templates:select ($node as element(select), $model) as element(select) {
    let $value := templates:resolve-key($model, $node/@name/string())
    let $options := $node/option
    return
        element select {
            $node/@*,
            if (empty($value)) then $options
            else
                for $option in $options
                let $selected := $option/@value = $value or $option/string() = $value
                return
                    element option {
                        $option/@* except $option/@selected,
                        if ($selected) then attribute selected { "selected" } else (),
                        $option/node()
                    }
        }
};

declare function templates:error-description($node as node(), $model as map(*)) as element() {
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

declare %private
function templates:copy-node($node as element(), $model as map(*)) as element() {
    element { node-name($node) } {
        $node/@*,
        templates:process-children($node/node(), $model)
    }
};

declare %private
function templates:shallow-copy-node($node as element(), $model as map(*)) as element() {
    element { node-name($node) } { $node/@* }
};
