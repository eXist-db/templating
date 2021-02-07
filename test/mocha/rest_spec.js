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

describe('Fail if template is missing', function() {
  it('fails if template could not be found', function () {
    return axiosInstance.get('template-missing.html')
      .catch(error => {
        expect(error.response.status).to.equal(400);
        expect(error.response.data).to.contain('templates:NotFound');
      });
  });
});