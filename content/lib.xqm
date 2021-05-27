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