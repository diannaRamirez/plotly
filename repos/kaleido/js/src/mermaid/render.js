/* global Mermaid:false */

const semver = require('semver')
const hasOwn = require('object.hasown')

if (!Object.hasOwn) {
	hasOwn.shim();
}

/**
 * @param {object} info : info object
 *  - data
 *  - format
 *  - width
 *  - height
 *  - scale
 */
function render (info) {

  // Rename info.data to info.markdown
  info.markdown = info.data
  delete info.data;
  
  let errorCode = 0
  let result = null
  let errorMsg = null
  let pdfBgColor = null
  
  const done = () => {
    if (errorCode !== 0 && !errorMsg) {
      errorMsg = cst.statusMsg[errorCode]
    }

    return {
      code: errorCode,
      message: errorMsg,
      pdfBgColor,
      format: info.format,
      result,
      width: info.width,
      height: info.height,
      scale: info.scale,
    }
  }

  let promise

  // TODO create different rendering call for v<10 and v>=10 of mermaidjs ?

  promise = mermaid.render("graph", info.markdown)

  let exportPromise = promise.then((imgData) => {
    result = imgData.svg
    return done()
  })

  return exportPromise
      .catch((err) => {
        errorCode = 525
        errorMsg = err.message
        result = null;
        return done()
      })
}

module.exports = render
