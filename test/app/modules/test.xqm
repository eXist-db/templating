xquery version "3.1";

module namespace test = "test";

declare namespace templates="http://exist-db.org/xquery/html-templating";

declare variable $test:app-root :=
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
    (: strip the xmldb: part :)
    if (starts-with($rawPath, "xmldb:exist://")) then
        if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
            substring($rawPath, 36)
        else
            substring($rawPath, 15)
    else
        $rawPath
    return
        substring-before($modulePath, "/modules")
;

declare 
    %templates:wrap
function test:init-data($node as node(), $model as map(*)) {
    let $addresses := (
        map {
            "name": "Berta Muh",
            "street": "An der Viehtränke 13",
            "city": "Kuhweide"
        },
        map {
            "name": "Rudi Rüssel",
            "street": "Am Zoo 45",
            "city": "Tierheim"
        }
    )
    return map {
        "addresses": $addresses,
        "data": map {
            "test": "TEST1",
            "nested": map {
                "test": "TEST2"
            }
        }
    }
};

declare 
    %templates:wrap
function test:print-name($node as node(), $model as map(*)) {
    $model("address")?name
};
declare 
    %templates:wrap
function test:print-city($node as node(), $model as map(*)) {
    $model("address")?city
};
declare 
    %templates:wrap
function test:print-street($node as node(), $model as map(*)) {
    $model("address")?street
};

declare 
    %templates:wrap
    %templates:default("language", "en")
function test:hello($node as node(), $model as map(*), $language as xs:string) {
    switch($language)
        case "de" return
            "Willkommen"
        case "pl" return
            "Witam"
        default return
            "Welcome"
};

declare 
    %templates:wrap
    %templates:default("defaultParam", "fallback")
function test:default($node as node(), $model as map(*), $defaultParam as xs:string) {
    $defaultParam
};

declare 
    %templates:wrap
function test:numbers($node as node(), $model as map(*), $n1 as xs:integer, $n2 as xs:double) {
    ($n1 treat as xs:integer) + ($n2 treat as xs:double)
};

declare
    %templates:wrap
function test:boolean($node as node(), $model as map(*), $boolean as xs:boolean) {
    if ($boolean instance of xs:boolean) then
        "yes"
    else
        "no"
};

declare 
    %templates:wrap
function test:date($node as node(), $model as map(*), $date as xs:date) {
    day-from-date($date)
};

declare function test:custom-model($node as node(), $model as map(*)) {
    $model?('my-model-item')
};

declare
    %templates:wrap
function test:print-from-class($node as node(), $model as map(*)) {
    'print-from-class'
};
