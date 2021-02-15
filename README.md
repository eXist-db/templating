# templating

[![License][license-img]][license-url]
[![GitHub release][release-img]][release-url]
![exist-db CI](https://github.com/eXist-db/templating/workflows/exist-db%20CI/badge.svg)
[![Coverage percentage][coveralls-image]][coveralls-url]

# eXist HTML Templating Library

This repository hosts the HTML templating library for eXist, which was previously part of the *shared-resources* package. *shared-resources* is now deprecated and users should upgrade their code. The new package intends to be backwards compatible: the namespace URI of the module has changed to avoid conflicts, but existing template functions will continue to work.

## Upgrading from *shared-resources*

1. change any dependency on `shared-resources` in your `expath-pkg.xml` to point to this package:

    ```xml
    <dependency package="http://exist-db.org/html-templating" semver-min="1.0.0"/>
    ```
2. update the module URI for any imports of the templating module:

    ```xquery
    import module namespace templates="http://exist-db.org/xquery/html-templating";
    ```

## Requirements

*   [exist-db](http://exist-db.org/exist/apps/homepage/index.html) version: `5.2.0` or greater

*   [node](http://nodejs.org) version: `12.x` \(for building from source\)

## Installation

1.  Install the *eXist-db HTML Templating Library* package from eXist's package repository via the [dashboard](http://localhost:8080/exist/apps/dashboard/index.html), or download  the `templating-1.0.0.xar` file from GitHub [releases](https://github.com/eXist-db/templating/releases) page.

2.  Open the [dashboard](http://localhost:8080/exist/apps/dashboard/index.html) of your eXist-db instance and click on `package manager`.

    1.  Click on the `add package` symbol in the upper left corner and select the `.xar` file you just downloaded.

3.  You have successfully installed templating into exist.

### Building from source

1.  Download, fork or clone this GitHub repository
2.  Calling `npm start` in your CLI will install required dependencies from npm and create a `.xar`:
  
```bash
cd templating
npm start
```

To install it, follow the instructions [above](#installation).

## Running Tests

This app uses [mochajs](https://mochajs.org) as a test-runner. To run the tests type:

```bash
npm test
```

This will automatically build and install the library plus a test application into your local eXist, assuming it can be reached on `http://localhost:8080/exist`. If this is not the case, edit `.existdb.json` and change the properties for the `localhost` server to match your setup.

## Contributing

You can take a look at the [Contribution guidelines for this project](.github/CONTRIBUTING.md)

## License

LGPL-3.0 © [eXist-db Project](http://exist-db.org)

[license-img]: https://img.shields.io/badge/license-LGPL%20v3-blue.svg
[license-url]: https://www.gnu.org/licenses/lgpl-3.0
[release-img]: https://img.shields.io/badge/release-1.0.0-green.svg
[release-url]: https://github.com/eXist-db/templating/releases/latest
[coveralls-image]: https://coveralls.io/repos/eXist-db/templating/badge.svg
[coveralls-url]: https://coveralls.io/r/eXist-db/templating
