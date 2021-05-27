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

describe('expand HTML template', function () {

  it('handles default and static parameters', async function () {
    const res = await axiosInstance.get('index.html');  
    expect(res.status).to.equal(200);
    const { window } = new JSDOM(res.data);

    // default parameter value applies
    expect(window.document.querySelector('h1.no-lang')).to.exist;
    expect(window.document.querySelector('h1.no-lang').innerHTML).to.equal('Welcome');
    // statically defined parameter
    expect(window.document.querySelector('h1.static-lang')).to.exist;
    expect(window.document.querySelector('h1.static-lang').innerHTML).to.equal('Witam');

    expect(window.document.querySelector('.custom').innerHTML).to.equal('Custom model item: xxx');
  });

  it('request parameter overwrites static default', async function () {
    const res = await axiosInstance.get('index.html', {
      params: {
        language: 'de'
      }
    });
    expect(res.status).to.equal(200);
    const { window } = new JSDOM(res.data);

    // default parameter value applies
    expect(window.document.querySelector('h1.no-lang')).to.exist;
    expect(window.document.querySelector('h1.no-lang').innerHTML).to.equal('Willkommen');
    // statically defined parameter
    expect(window.document.querySelector('h1.static-lang')).to.exist;
    expect(window.document.querySelector('h1.static-lang').innerHTML).to.equal('Willkommen');
  });

  it('converts parameter types', async function () {
    const res = await axiosInstance.get('types.html', {
      params: {
        n1: 20,
        n2: 30.25,
        date: '2021-02-07+01:00'
      }
    });
    expect(res.status).to.equal(200);
    const { window } = new JSDOM(res.data);

    // default parameter value applies
    expect(window.document.querySelector('p.numbers')).to.exist;
    expect(window.document.querySelector('p.numbers').innerHTML).to.equal('50.25');
    expect(window.document.querySelector('p.date').innerHTML).to.equal('7');
  });

  it('rejects wrong parameter type', function () {
    return axiosInstance.get('types-fail.html', {
      params: {
        n1: 'abc',
        n2: 30.25,
        date: '2021-02-07+01:00'
      }
    })
      .catch(error => {
        expect(error.response.status).to.equal(400);
        expect(error.response.data).to.contain('templates:TypeError');
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
  it('injects form field values', async function() {
    const res = await axiosInstance.get('forms.html', {
      params: {
        param1: 'xxx',
        param2: 'value2',
        param3: true,
        param4: 'radio2'
      }
    });
    expect(res.status).to.equal(200);
    const { window } = new JSDOM(res.data);

    // default parameter value applies
    const control1 = window.document.querySelector('input[name="param1"]');
    expect(control1).to.exist;
    expect(control1.value).to.equal('xxx');

    const control2 = window.document.querySelector('select[name="param2"]');
    expect(control2).to.exist;
    expect(control2.value).to.equal('value2');

    const control3 = window.document.querySelector('input[name="param3"]');
    expect(control3).to.exist;
    expect(control3.checked).to.be.true;

    const control4 = window.document.querySelectorAll('input[name="param4"]');
    expect(control4).to.have.length(2);
    expect(control4[0].checked).to.be.false;
    expect(control4[1].checked).to.be.true;
  });
});

describe('Supports set and unset param', function() {
  it('supports set and unset with multiple params of the same name', async function() {
    const res = await axiosInstance.get('set-unset-params.html?foo=bar&foo=baz'
    // if URL parameters are supplied via params object, mocha will only send one param 
    // of a given name, so we must include params in the query string
    );
    expect(res.status).to.equal(200);
    const { window } = new JSDOM(res.data);
    
    expect(window.document.querySelector('p#set')).to.exist;
    });
});

describe('Fail if template is missing', function() {
  it('fails if template could not be found', function () {
    return axiosInstance.get('template-missing.html')
      .catch(error => {
        expect(error.response.status).to.equal(400);
        expect(error.response.data).to.contain('templates:NotFound');
      });
  });
});