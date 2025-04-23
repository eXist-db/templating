xquery version "3.1";

(:~
 : HTML templating utility module
 :
 : @contributor Juri Leino
:)
module namespace tmpl-util="http://exist-db.org/xquery/html-templating/utility";

declare
function tmpl-util:cast ($values as item()*, $targetType as xs:string) {
    for $value in $values
    return
        (: treat "" as empty sequence :)
        if ($targetType != "xs:string" and string-length($value) = 0)
        then ()
        else
            switch ($targetType)
                case "xs:boolean"  return xs:boolean($value)
                case "xs:string"   return string($value)
                case "xs:integer"  return xs:integer($value)
                case "xs:int"      return xs:int($value)
                case "xs:long"     return xs:long($value)
                case "xs:decimal"  return xs:decimal($value)
                case "xs:float"    return xs:float($value)
                case "xs:double"   return xs:double($value)
                case "xs:date"     return xs:date($value)
                case "xs:dateTime" return xs:dateTime($value)
                case "xs:time"     return xs:time($value)
                case "element()"   return parse-xml($value)/*
                case "text()"      return text { string($value) }
                default            return $value
};

declare
function tmpl-util:first-result ($fns as function(*)*, $arg as item()*) as item()* {
    if (empty($fns)) then (
    ) else (
        let $result := head($fns)($arg)
        return
            if (exists($result)) then (
                $result
            ) else (
                tmpl-util:first-result(tail($fns), $arg)
            )
    )
};

declare
function tmpl-util:first-qname-like ($class as attribute(class)) as xs:string? {
    head(
        tokenize($class, "\s+")
            [matches(., "^[^:]+:[^:]+")])
};

declare
function tmpl-util:resolve-fn(
    $function-name as xs:string,
    $resolve as function(*),
    $max-arity as xs:integer
) as function(*)? {
    fold-left(2 to $max-arity, (), function ($fn, $arity) {
        if (exists($fn)) then $fn
        else $resolve($function-name, $arity)
    })
};
