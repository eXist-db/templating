# templating

[![License][license-img]][license-url]
[![GitHub release][release-img]][release-url]
![exist-db CI](https://github.com/eXist-db/templating/workflows/exist-db%20CI/badge.svg)
[![Coverage percentage][coveralls-image]][coveralls-url]

<img src="icon.png" align="left" width="25%"/>

eXist-db HTML Templating Library

## Requirements

*   [exist-db](http://exist-db.org/exist/apps/homepage/index.html) version: `5.x` or greater

*   [node](http://nodejs.org) version: `12.x` \(for building from source\)

## Installation

1.  Download  the `templating-1.0.0.xar` file from GitHub [releases](https://github.com/eXist-db/templating/releases) page.

2.  Open the [dashboard](http://localhost:8080/exist/apps/dashboard/index.html) of your eXist-db instance and click on `package manager`.

    1.  Click on the `add package` symbol in the upper left corner and select the `.xar` file you just downloaded.

3.  You have successfully installed templating into exist.

### Building from source

1.  Download, fork or clone this GitHub repository
2.  There are two default build targets in `build.xml`:
    *   `dev` including *all* files from the source folder including those with potentially sensitive information.
  
    *   `deploy` is the official release. It excludes files necessary for development but that have no effect upon deployment.
  
3.  Calling `ant`in your CLI will build both files:
  
```bash
cd templating
ant
```

   1. to only build a specific target call either `dev` or `deploy` like this:
   ```bash   
   ant dev
   ```   

If you see `BUILD SUCCESSFUL` ant has generated a `templating-1.0.0.xar` file in the `build/` folder. To install it, follow the instructions [above](#installation).



## Running Tests

To run tests locally your app needs to be installed in a running exist-db instance at the default port `8080` and with the default dba user `admin` with the default empty password.

A quick way to set this up for docker users is to simply issue:

```bash
docker run -dit -p 8080:8080 existdb/existdb:release
```

After you finished installing the application, you can run the full testsuite locally.

### Unit-tests

This app uses [mochajs](https://mochajs.org) as a test-runner. To run both xquery and javascript unit-tests type:

```bash
npm test
```


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
