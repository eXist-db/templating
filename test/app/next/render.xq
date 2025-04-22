xquery version "3.1";

import module namespace templates="http://exist-db.org/xquery/html-templating";

import module namespace test="test" at "../modules/test.xqm";

declare namespace render="html-templating/render.xq";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html";
declare option output:html-version "5";
declare option output:media-type "text/html";

declare variable $render:root := '/db/apps/templating-test';
declare variable $render:filter := xs:boolean(request:get-parameter('filter', 'true'));

templates:render(
    doc($render:root || '/next/page.html'), (: root template :)
    json-doc($render:root || '/next/data.json'), (: json data :)
    map {
        $templates:CONFIG_APP_ROOT          : $render:root,
        $templates:CONFIG_QNAME_RESOLVER    : xs:QName(?),
        $templates:CONFIG_FILTER_ATTRIBUTES : $render:filter,
        $templates:CONFIG_STOP_ON_ERROR     : true(),
        $templates:CONFIG_ATTR_PREFIX       : 'τ-'
    }
)
