xquery version "3.1";

import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace lib="http://exist-db.org/xquery/html-templating/lib";


import module namespace test="test" at "test.xqm";


declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";


let $config := map {
    $templates:CONFIG_APP_ROOT      : $test:app-root,
    $templates:CONFIG_STOP_ON_ERROR : true()
}

(: read request parameter first in order to test three states
 : true, false and unset / default
 :)
let $class-syntax-option := request:get-parameter('classLookup', ())
let $config-with-class-syntax-maybe-set := 
    if (empty($class-syntax-option)) then (
        $config
    ) else (
        map:put($config, $templates:CONFIG_USE_CLASS_SYNTAX, xs:boolean($class-syntax-option))
    )

(:
 : The HTML is passed in the request from the controller.
 : Run it through the templating system and return the result.
 :)
return
templates:apply(
    request:get-data(), 
    xs:QName(?),
    map { "my-model-item": 'xxx' },
    $config-with-class-syntax-maybe-set)

(: alternative :)
(:
templates:render(
    request:get-data(),
    map { "my-model-item": 'xxx' },
    map {
        $templates:CONFIG_FN_RESOLVER   : xs:QName(?),
        $templates:CONFIG_APP_ROOT      : $test:app-root,
        $templates:CONFIG_STOP_ON_ERROR : true()
    })
:)
