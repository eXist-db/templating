'use strict'

const axios = require('axios');
const expect = require('chai').expect;
const jsdom = require('jsdom');
const { JSDOM } = jsdom;
const existJSON = require('../../.existdb.json');
const serverInfo = existJSON.servers.localhost;

const { origin } = new URL(serverInfo.server);
const app = `${origin}/exist/apps/templating-test`;

const axiosInstance = axios.create({
  baseURL: app
});

describe('expand HTML template index.html', function () {
  let document, res

  before(async function () {
    try {
      res = await axiosInstance.get('index.html');
      const {window} = new JSDOM(res.data);
      document = window.document
    }
    catch (e) { console.log(e.response.data) }
  })

  it('returns status ok', async function () {
    expect(res.status).to.equal(200);
    expect(document).to.be.ok;
  });

  it('handles default parameters', async function () {
    // default parameter value applies
    expect(document.querySelector('h1.no-lang')).to.exist;
    expect(document.querySelector('h1.no-lang').innerHTML).to.equal('Welcome');
  });

  it('handles static parameters', async function () {
      // statically defined parameter
    expect(document.querySelector('h1.static-lang')).to.exist;
    expect(document.querySelector('h1.static-lang').innerHTML).to.equal('Witam');
  });

  it('handles custom model items', async function () {
    expect(document.querySelector('.custom').innerHTML).to.equal('Custom model item: xxx');
  });

  it('handles fallbacks', async function () {
    expect(document.querySelector('.default-param').innerHTML).to.equal('fallback');
  });
});

describe('expand HTML template index.html with language parameter set', function () {
  let document, res

  before(async function () {
    res = await axiosInstance.get('index.html', {
      params: {
        language: 'de'
      }
    });
    const { window } = new JSDOM(res.data);
    document = window.document
  })

  it('request returns with status 200', async function () {
    expect(res.status).to.equal(200);
    expect(document).to.be.ok;
  });

  it('request parameter overwrites default', async function () {
    // default parameter value applies
    expect(document.querySelector('h1.no-lang')).to.exist;
    expect(document.querySelector('h1.no-lang').innerHTML).to.equal('Willkommen');
  });

  it('request parameter overwrites static', async function () {
      // statically defined parameter
    expect(document.querySelector('h1.static-lang')).to.exist;
    expect(document.querySelector('h1.static-lang').innerHTML).to.equal('Willkommen');
  });
});

describe('expand HTML template types.html', function () {
  let document, res

  before(async function () {
    res = await axiosInstance.get('types.html', {
      params: {
        n1: 20,
        n2: 30.25,
        date: '2021-02-07+01:00',
        boolean: 'true'
      }
    });
    const { window } = new JSDOM(res.data);
    document = window.document
  })
  
  it('returns with status OK', async function () {
    expect(res.status).to.equal(200);
    expect(document).to.be.ok;
  });

  it('converts numbers', async function () {
    // default parameter value applies
    expect(document.querySelector('p.numbers')).to.exist;
    expect(document.querySelector('p.numbers').innerHTML).to.equal('50.25');
  });

  it('converts dates', async function () {
    expect(document.querySelector('p.date').innerHTML).to.equal('7');
  });

  it('converts booleans', async function () {
    expect(document.querySelector('p.boolean').innerHTML).to.equal('yes');
  });
});

describe('expand HTML template types-fail.html', function () {

  it('rejects wrong parameter type', function () {
    return axiosInstance.get('types-fail.html', {
      params: {
        n1: 'abc',
        n2: 30.25,
        date: '2021-02-07+01:00',
        boolean: 'true'
      }
    })
      .catch(error => {
        expect(error.response.status).to.be.oneOf([400, 500]);
        expect(error.response.data).to.contain('templates:TypeError');
      });
  });

});

describe('expand HTML template missing-tmpl.html', function () {

  it("reports missing template functions", async function () {
		return axiosInstance.get("missing-tmpl.html")
			.catch((error) => {
				expect(error.response.status).to.be.oneOf([400, 500]);
				expect(error.response.data).to.contain("templates:NotFound");
			});
  });
});

describe('Supports template nesting', function() {
  it('handles nested templates', async function() {
    const res = await axiosInstance.get('nesting.html');
    expect(res.status).to.equal(200);
    const { window } = new JSDOM(res.data);

    expect(window.document.querySelector('tr:nth-child(1) td[data-template="test:print-name"]').innerHTML).to.equal('Berta Muh');
    expect(window.document.querySelector('tr:nth-child(2) td[data-template="test:print-street"]').innerHTML).to.equal('Am Zoo 45');
  });
});

describe('Supports form fields', function() {
  let res, document
  before(async function () {
    try {
      res = await axiosInstance.get('forms.html', {
        params: {
          param1: 'xxx',
          param2: 'value2',
          param3: true,
          param4: 'checkbox2',
          param5: 'radio2'
        }
      });
      const { window } = new JSDOM(res.data);
      document = window.document
    }
    catch (e) { 
      return console.log(e.response.data)
    }
  })

  it('is rendered without errors', async function() {
    expect(res.status).to.equal(200);
  })

  it('injects form field value in text field', async function() {
    // default parameter value applies
    const control1 = document.querySelector('input[name="param1"]');
    expect(control1).to.exist;
    expect(control1.value).to.equal('xxx');
  })

  it('selects option in select', async function() {
    const control2 = document.querySelector('select[name="param2"]');
    expect(control2).to.exist;
    expect(control2.value).to.equal('value2');
  })

  it('checks checkbox without value attribute', async function() {
    const control3 = document.querySelector('input[name="param3"]');
    expect(control3).to.exist;
    expect(control3.checked).to.be.true;

  })

  it('checks checkboxes with value attribute', async function() {
    const control4 = document.querySelectorAll('input[name="param4"]');
    expect(control4).to.have.length(2);
    expect(control4[0].checked).to.be.false;
    expect(control4[1].checked).to.be.true;
    
  })

  it('injects form field values', async function() {
    const control5 = document.querySelectorAll('input[name="param5"]');
    expect(control5).to.have.length(2);
    expect(control5[0].checked).to.be.false;
    expect(control5[1].checked).to.be.true;
  });
});

describe('Supports set and unset param', function() {
  it('supports set and unset with multiple params of the same name', async function() {
    let res
    try {
      res = await axiosInstance.get('set-unset-params.html?foo=bar&foo=baz'
      // if URL parameters are supplied via params object, mocha will only send one param 
      // of a given name, so we must include params in the query string
      );
    }
    catch (e) {
      return console.error(e.response.data)
    }

    expect(res.status).to.equal(200);
    const { window } = new JSDOM(res.data);
    
    expect(window.document.querySelector('p#set')).to.exist;
  });
});

describe("Supports parsing parameters", function () {
  let res, document

  before(async function () {
    try {
      res = await axiosInstance.get("parse-params.html", {
          params: {
            description: 'my title',
            link: 'foo'
          }
      });
      const { window } = new JSDOM(res.data);
      document = window.document
    }
    catch (e) {
      console.error(e.response.data)
    }
  })

  it("renders the page without errors", async function () {
		expect(res.status).to.equal(200);
  });

  it("supports parsing parameters in attributes and text", async function () {
    const link = document.querySelector("a");
    expect(link).to.exist;
		expect(link.title).to.equal('Link: my title');
    expect(link.href).to.equal('/api/foo/');
	});

  it("supports expanding from model", async function () {
		const para = document.getElementById('nested');
		expect(para).to.exist;
		expect(para.innerHTML).to.equal("Out: TEST2");

    const li = document.querySelectorAll('li');
    expect(li).to.have.lengthOf(2);
    expect(li[0].innerHTML).to.equal("Berta Muh, Kuhweide");
    expect(li[1].innerHTML).to.equal("Rudi Rüssel, Tierheim");
  });

  it("fails gracefully", async function () {
    const para = document.getElementById('default');
    expect(para).to.exist;
    expect(para.innerHTML).to.equal("not found;not found;");
  });

  it("serializes maps and arrays to JSON", async function () {
		const para = document.getElementById("map");
		expect(para).to.exist;
		expect(para.innerHTML).to.equal('{"test":"TEST2"}');
  });

  it("handles different delimiters", async function () {
		let para = document.getElementById("delimiters1");
		expect(para).to.exist;
		expect(para.innerHTML).to.equal('my title');

    para = document.getElementById("delimiters2");
	  expect(para).to.exist;
	  expect(para.innerHTML).to.equal("TITLE: my title");
  });
});

describe('Fail if template is missing', function() {
  it('fails if template could not be found', function () {
    return axiosInstance.get('template-missing.html')
      .then(res => console.error(res.status))
      .catch(error => {
        expect(error.response.status).to.be.oneOf([400, 500]);
        expect(error.response.data).to.contain('templates:NotFound');
      });
  });
});

describe("Supports including another file", function () {
	it("replaces target blocks in included file", async function () {
		const res = await axiosInstance.get("includes.html", {
      params: { title: 'my title' }
    });
		expect(res.status).to.equal(200);
		const { window } = new JSDOM(res.data);

    const items = window.document.querySelectorAll("li");
    expect(items).to.have.lengthOf(4);
    expect(items[0].getAttribute('title')).to.equal('my title');
    expect(items[0].innerHTML).to.equal('Block inserted at "start"');
    expect(items[1].innerHTML).to.equal('First');
    expect(items[3].innerHTML).to.equal('Block inserted at "end"');
  });
});

describe("Supports resolving app location", function() {
  this.timeout(10000);
  it("replaces variable with app URL", async function () {
		const res = await axiosInstance.get("resolve-apps.html");
		expect(res.status).to.equal(200);
		const { window } = new JSDOM(res.data);
    let para = window.document.getElementById('test1');
    expect(para.innerHTML).to.equal("/exist/apps/templating-test");

    para = window.document.getElementById("test2");
	  expect(para.innerHTML).to.equal("/exist/404.html#");
  });
});

describe('Templates can be called from class', function () {
  it('and will not be expanded when $templates:CONFIG_USE_CLASS_SYNTAX is not set', async function () {
    const res = await axiosInstance.get('call-from-class.html', {
      params: {},
    });
    expect(res.status).to.equal(200);
    const { window } = new JSDOM(res.data);
    expect(window.document.querySelector('p').innerHTML).to.equal('');
  });

  it('and will be expanded when $templates:CONFIG_USE_CLASS_SYNTAX is true()', async function () {
    const res = await axiosInstance.get('call-from-class.html', {
      params: {
        classLookup: true,
      },
    });
    expect(res.status).to.equal(200);
    const { window } = new JSDOM(res.data);
    expect(window.document.querySelector('p').innerHTML).to.equal(
      'print-from-class'
    );
  });

  it('and will not be expanded when $templates:CONFIG_USE_CLASS_SYNTAX is false()', async function () {
    const res = await axiosInstance.get('call-from-class.html', {
      params: {
        classLookup: false,
      },
    });
    expect(res.status).to.equal(200);
    const { window } = new JSDOM(res.data);
    expect(window.document.querySelector('p').innerHTML).to.equal('');
  });
});
