xquery version "3.1";

(:~
 : HTML templating module: utility template functions.
 : Newly added templating functions should go here and not into templates.xqm.
 :
 : @author Wolfgang Meier
:)
module namespace lib="http://exist-db.org/xquery/html-templating/lib";

import module namespace templates="http://exist-db.org/xquery/html-templating";

(:~
 : Include an HTML fragment from another file as given in parameter $path.
 : The children (if any) of the including element (i.e. the one triggering the lib:include function)
 : are merged into the included content. To define where a child element should be
 : inserted, you must use a @data-target attribute referencing an HTML id which must exist
 : within the included fragment. If @data-target is missing, the element will be discarded. 
 : 
 : This is a mechanism to inject content from the including element into the included content. For example, if the same menu
 : or toolbar is included into every page of an application, but some pages should have
 : additional options, you can use lib:include with lib:block to define the additional HTML
 : to be inserted in a specific place.
 :
 : This is an extended version of templates:include.
 :)
declare function lib:include($node as node(), $model as map(*), $path as xs:string) {
    let $appRoot := templates:get-app-root($model)
    let $root := templates:get-root($model)
    let $path :=
        if (starts-with($path, "/")) then
            (: Search template relative to app root :)
            concat($appRoot, "/", $path)
        else if (matches($path, "^https?://")) then
            (: Template is loaded from a URL, this template even if a HTML file, must be
               returned with mime-type XML and be valid XML, as it is retrieved with fn:doc() :)
            $path
        else
            (: Locate template relative to HTML file :)
            concat($root, "/", $path)
    let $doc := doc($path)
    return
        if ($doc) then
            templates:process(lib:expand-blocks($node, $doc), $model)
        else
            <p>Include not found: {$path}</p>
};

(:~
 : Collect the children of the current element into a map, grouped by @data-target.
 : Then call lib:expand-blocks-recursive to replace the corresponding target nodes
 : in the included content with the collected HTML nodes.
 :)
declare %private function lib:expand-blocks($context as node(), $included as document-node()) {
    map:merge(
        for $blocks in $context/*[@data-target]
        group by $name := $blocks/@data-target
        return
            map:entry($name, $blocks)
    )
    => lib:expand-blocks-recursive($included)
};

declare %private function lib:expand-blocks-recursive($blocks as map(*), $nodes as node()*) {
    for $node in $nodes
    return
        typeswitch ($node)
            case document-node() return
                lib:expand-blocks-recursive($blocks, $node/node())
            case element() return
                if ($node/@id and map:contains($blocks, $node/@id)) then
                    $blocks($node/@id)
                else
                    element { node-name($node) } {
                        $node/@*,
                        lib:expand-blocks-recursive($blocks, $node/node())
                    }
            default return
                $node
};

(:~
 : Recursively expand template expressions appearing in attributes or text content,
 : trying to expand them from request/session parameters or the current model.
 :
 : Template expressions should have the form ${paramName:default text}.
 : Specifying a default is optional. If there is no default and the parameter
 : cannot be expanded, the empty string is output.
 :
 : To support navigating the map hierarchy of the model, paramName may be a sequence 
 : of map keys separated by ?, i.e. ${address?street} would first retrieve the map
 : property called "address" and then look up the property "street" on it.
 :
 : The templating function should fail gracefully if a parameter or map lookup cannot
 : be resolved, a lookup resolves to multiple items, a map or an array.
 :)
declare function lib:parse-params($node as node(), $model as map(*)) {
    element { node-name($node) } {
        lib:expand-attributes($node/@* except $node/@data-template, $model),
        lib:expand-params($node/node(), $model)
    }
    => templates:process($model)
};

declare %private function lib:expand-params($nodes as node()*, $model as map(*)) {
    for $node in $nodes
    return
        typeswitch($node)
            case element() return
                element { node-name($node) } {
                    lib:expand-attributes($node/@*, $model),
                    lib:expand-params($node/node(), $model)
                }
            case text() return
                if (matches($node, "\$\{[^\}]+\}")) then
                    text { lib:expand-text($node, $model) }
                else
                    $node
            default return
                $node
};

declare %private function lib:expand-attributes($attrs as attribute()*, $model as map(*)) {
    for $attr in $attrs
    return
        if (matches($attr, "\$\{[^\}]+\}")) then
            attribute { node-name($attr) } {
                lib:expand-text($attr, $model)
            }
        else
            $attr
};

declare %private function lib:expand-text($text as xs:string, $model as map(*)) {
    string-join(
        let $parsed := analyze-string($text, "\$\{([^\}]+?)(?::([^\}]+))?\}")
        for $token in $parsed/node()
        return
            typeswitch($token)
                case element(fn:non-match) return $token/string()
                case element(fn:match) return
                    let $paramName := $token/fn:group[1]/string()
                    let $default := $token/fn:group[2]/string()
                    let $param := $model($templates:CONFIGURATION)($templates:CONFIG_PARAM_RESOLVER)($paramName)
                    let $values :=
                        if (exists($param)) then
                            $param
                        else
                            let $modelVal := lib:expand-from-model($paramName, $model)
                            return
                                if (exists($modelVal)) then $modelVal else $default
                    return
                        for $value in $values
                        return
                            typeswitch($value)
                                case map(*) | array(*) return serialize($value, map { "method": "json" })
                                default return $value
                default return $token
    )
};

declare %private function lib:expand-from-model($paramName as xs:string, $model as map(*)) {
    tokenize($paramName, '\?') => fold-left($model, function($context as item()*, $param as xs:string) {
        if ($context instance of map(*)) then
            $context($param)
        else
            ()
    })
};