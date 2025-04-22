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

describe('next templating', function () {
  let document, res

  before(async function () {
    try {
      res = await axiosInstance.get('next');
      const {window} = new JSDOM(res.data);
      document = window.document
    }
    catch (e) { console.log(e.response.data) }
  })

  it('returns status ok', async function () {
    expect(res.status).to.equal(200);
    expect(document).to.be.ok;
  });

  it('handles static parameters', async function () {
    const el = document.querySelector('h1[class="static:lang"]')
    expect(el).to.exist;
    expect(el.innerHTML).to.equal('Witam');
  });

  it('handles loops', async function() {
    const addresses = document.querySelectorAll('address');
    expect(addresses[0].innerHTML).to.equal(`
Berta Muh
An der Viehtränke 13
Kuhweide
        `);
    expect(addresses[1].innerHTML).to.equal(`
Rudi Rüssel
Am Zoo 45
Tierheim
        `);
  });
});

describe("When not filtering attributes", function () {
  let res, document

  before(async function () {
    try {
      res = await axiosInstance.get("next", {
          params: {
            filter: "false"
          }
      });
      const { window } = new JSDOM(res.data);
      document = window.document
    }
    catch (e) {
      console.error(e.response.data)
    }
  })

  it("renders the page without errors", function () {
    expect(res.status).to.equal(200);
    expect(document).to.be.ok;
  });

  it("Template elements can be found in DOM using attribute selectors", function () {
    const elementsWithTemplateFunctionAttributes = document.querySelectorAll("[τ-fn]");
    expect(elementsWithTemplateFunctionAttributes).to.exist;
    expect(elementsWithTemplateFunctionAttributes.length).to.equal(3);
  });
});