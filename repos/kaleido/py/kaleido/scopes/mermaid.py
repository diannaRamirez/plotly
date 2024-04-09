from kaleido.scopes.base import BaseScope
import json
import shlex


class MermaidScope(BaseScope):
    """
    Scope for transforming Mermaid figures to static images
    """
    _all_formats = ("svg")
    _text_formats = ("svg")

    _scope_flags = ("mermaidjs", "mermaid_config")
    _scope_chromium_args = ("--no-sandbox",)

    def __init__(self, mermaidjs=None, mermaid_config=None, diagram_config=None, **kwargs):

        self._mermaidjs = mermaidjs 

        self.default_format = "svg"
        self.default_width = 700
        self.default_height = 500
        self.default_scale = 1
        self.default_mermaid_config = {"startOnLoad": False}

        self._initialize_mermaid_config(mermaid_config)
        self._initialize_diagram_config(diagram_config)
        
        super(MermaidScope, self).__init__(**kwargs)

    def _initialize_mermaid_config(self, mermaid_config):
        self._mermaid_config = mermaid_config if mermaid_config is not None else self.default_mermaid_config
        self._mermaid_config = json.dumps(self._mermaid_config).replace(" ", "") 

    def _initialize_diagram_config(self, diagram_config):
        self._diagram_config = diagram_config if diagram_config is not None else {}
        self._diagram_config = json.dumps(self._diagram_config).replace(" ", "") 

    @property
    def scope_name(self):
        return "mermaid"

    
    def transform(self, markdown, format=None, width=None, height=None, scale=None, config=None):
        """
        Convert a Mermaid markdown into a static image

        :param markdown: Mermaid graph definition in markdown
        :param format: The desired image format. For now, just 'svg' is supported.
           
        :param width: The width of the exported image in layout pixels.
            If the `scale` property is 1.0, this will also be the width
            of the exported image in physical pixels.

            If not specified, will default to the `scope.default_width` property
        :param height: The height of the exported image in layout pixels.
            If the `scale` property is 1.0, this will also be the height
            of the exported image in physical pixels.

            If not specified, will default to the `scope.default_height` property
        :param scale: The scale factor to use when exporting the figure.
            A scale factor larger than 1.0 will increase the image resolution
            with respect to the figure's layout pixel dimensions. Whereas as
            scale factor of less than 1.0 will decrease the image resolution.

            If not specified, will default to the `scope.default_scale` property
        :return: image bytes
        """
       
        format = format.lower() if format is not None else self.default_format
        width = width if width is not None else self.default_width
        height = height if height is not None else self.default_height
        scale = scale if scale is not None else self.default_scale
        
        self._initialize_diagram_config(config)

        if format not in self._all_formats:
            supported_formats_str = repr(list(self._all_formats))
            raise ValueError(
                "Invalid format '{original_format}'.\n"
                "    Supported formats: {supported_formats_str}"
                .format(
                    original_format=format,
                    supported_formats_str=supported_formats_str
                )
            )

        response = self._perform_transform(markdown, format=format, width=width, height=height, scale=scale, config=self._diagram_config)

        code = response.get("code", 0)
        if code != 0:
            message = response.get("message", None)
            raise ValueError(
                "Transform failed with error code {code}: {message}".format(
                    code=code, message=message
                )
            )

        img = response.get("result").encode("utf-8")

        # TODO add decodings for non-text image formats

        return img
    

    @property
    def mermaidjs(self):
        """
        URL or local file path to mermaid.js bundle to use for image export.
        If not specified, will default to CDN location.
        """
        return self._mermaidjs

    @mermaidjs.setter
    def mermaidjs(self, val):
        self._mermaidjs = val

    
    @property
    def mermaid_config(self):
        """
        Config object for mermaid initialization. 
        If not specified, default mermaid configuration will be used.
        """
        return self._mermaid_config

    @mermaid_config.setter
    def mermaid_config(self, val):
        self._mermaid_config = val