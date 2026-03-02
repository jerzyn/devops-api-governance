spectral-ruleset.yaml
extends: [[spectral:oas, all]]
functions:
  [
    "disallowedNullInTypeArray",
    "disallowedNullInTypeArrayAndObjects",
    "logAndHelp",
    "validatePathParamsNaming",
    "checkTableNamePlural",
  ]
formats: ["oas3"]
rules:
  operation-success-response: error # This rule checks if each operation defines at least one successful HTTP response.

  # ----------------#
  # Overridden rules #
  # ----------------#

  openapi-tags-alphabetical:
    description: "OpenAPI object SHOULD have alphabetical 'tags'"
    message: "OpenAPI object SHOULD have alphabetical 'tags'"
    severity: "warn"
    given: "$"
    then:
      field: "tags"
      function: alphabetical
      functionOptions:
        keyedBy: "name"

  license-url:
    description: "License object SHOULD include 'url'."
    message: "License object SHOULD include 'url'."
    severity: "warn"
    given: "$"
    then:
      field: "info.license.url"
      function: truthy

  operation-singular-tag:
    description: "Operation SHOULD NOT have more than a single tag."
    message: "Operation SHOULD NOT have more than a single tag."
    severity: "warn"
    given: "$.paths[*][get,put,post,delete,options,head,patch,trace]"
    then:
      field: "tags"
      function: length
      functionOptions:
        max: 1

  # ----------#
  # PZU rules #
  # ----------#

  # Require 'openapi' version property format x.y.z
  # this rule will not even be triggered if formats: ['oas3'] is added
  pzu:rest1:2025-openapi:
    description: "API MUST be described using OpenAPI format and MUST comply with OpenAPI Specification version 3.x.y."
    message: "OpenAPI version MUST be 3.x.y. . \n https://api-guidelines.app.pzu.pl/rest/#openapi-specification-pzurest12025-openapi"
    severity: "error"
    given: "$.openapi"
    then:
      function: "pattern"
      functionOptions:
        match: "^3\\.\\d+\\.\\d+$"

  pzu:rest1:2025-openapi-31:
    description: "API MUST be described using OpenAPI format and SHOULD comply with OpenAPI Specification version 3.1.y."
    message: "OpenAPI version SHOULD be 3.1.y.\n https://api-guidelines.app.pzu.pl/rest/#openapi-specification-pzurest12025-openapi"
    severity: "warn"
    given: "$.openapi"
    then:
      function: "pattern"
      functionOptions:
        match: "^3\\.1\\.\\d+$"

  # Require 'info' property
  pzu:rest2:2025-openapi-info-required:
    description: "'info' MUST be defined in the OpenAPI document."
    message: "'info' object MUST be present. \n https://api-guidelines.app.pzu.pl/rest/#openapi-specification-pzurest12025-openapi"
    severity: "error"
    given: "$"
    then:
      function: "schema"
      functionOptions:
        schema:
          type: "object"
          required: ["info"]

  # Require 'info.version' property
  pzu:rest2:2025-openapi-version-required:
    description: "'info.version' MUST be defined in the OpenAPI document."
    message: "'info.version' property MUST be present. \n https://api-guidelines.app.pzu.pl/rest/#openapi-specification-pzurest12025-openapi"
    severity: "error"
    given: "$"
    then:
      function: "schema"
      functionOptions:
        schema:
          type: "object"
          properties:
            info:
              type: "object"
              required: ["version"]

  # Enforce 'info.version' format x.y.z
  pzu:general5:2025-semver:
    description: "'info.version' MUST use semantic versioning (MAJOR.MINOR.PATCH, e.g., 1.0.3)."
    message: "'info.version' MUST use semantic versioning (MAJOR.MINOR.PATCH, e.g., 1.0.3). \n https://api-guidelines.app.pzu.pl/general-guidelines/#semver-pzugeneral52025-semver"
    severity: "error"
    given: "$.'info.version'"
    then:
      function: "pattern"
      functionOptions:
        match: "^\\d+\\.\\d+\\.\\d+$"

  # Require 'info.title' property
  pzu:rest11:2025-api-naming-required:
    description: "'info.title' property MUST be present."
    message: "'`info.title'` property MUST be present. \n https://api-guidelines.app.pzu.pl/rest/#nazwa-api-pzurest112025-api-naming"
    severity: "error"
    given: "$"
    then:
      function: "schema"
      functionOptions:
        schema:
          type: "object"
          properties:
            info:
              type: "object"
              required: ["title"]

  # API name must be Title Case and end with 'API'
  pzu:rest11:2025-api-naming-format:
    description: "The API name ('info.title') MUST be written in Title Case (each word starts with a capital letter) and MUST end with the word 'API'."
    message: "'info.title' must be Title Case and end with 'API'. \n https://api-guidelines.app.pzu.pl/rest/#nazwa-api-pzurest112025-api-naming"
    severity: "error"
    given: "$.info.title"
    then:
      function: "pattern"
      functionOptions:
        match: "^([A-Z][a-z0-9]+\\s)*[A-Z][a-z0-9]+ API$"

  pzu:general11:2025-json-general-naming-conventions:
    description: "Each JSON property identifier SHOULD be written in camelCase (https://en.wikipedia.org/wiki/Camel_case)."
    message: "Property identifier '{{property}}' SHOULD be in camelCase. \n https://api-guidelines.app.pzu.pl/general-guidelines/#json-pzugeneral112025-json"
    severity: "warn"
    given:
      - $.components..properties[*]~
      - $.paths[*][*].responses[*].content[*].schema..properties[*]~
      - $.paths[*][*]..properties.*~
    then:
      function: "pattern"
      functionOptions:
        match: "^(_link|_?[a-z]+([A-Z][a-z]+)*)$"

  pzu:general12:2025-json-object-name:
    description: "Each JSON object definition SHOULD be written in PascalCase (https://pl.wikipedia.org/wiki/PascalCase)."
    message: "JSON object identifier '{{property}}' SHOULD be in PascalCase. \n https://api-guidelines.app.pzu.pl/general-guidelines/#definicje-obiektow-json-w-openapi-pzugeneral122025-json-object-name"
    severity: "warn"
    given:
      - $.components.schemas[*]~
    then:
      function: "pattern"
      functionOptions:
        match: "^([A-Z][a-z]+)+$"

  # Field names must consist of ASCII alphanumeric characters, underscores (_) or dollar sign ($)
  pzu:general11:2025-json-general-naming-conventions-ASCII:
    description: "Field names MUST consist of ASCII alphanumeric characters, underscore (_) or dollar sign ($)."
    message: "The name of JSON property '{{property}}' MUST use only ASCII letters, digits, underscore (_), or dollar sign ($). \n https://api-guidelines.app.pzu.pl/general-guidelines/#json-pzugeneral112025-json"
    severity: "error"
    given:
      - $.paths[*][*]..properties.*~
      - $.components..properties[*]~
      - $.components.schemas[*]~
      - $.paths[*][*].responses[*].content[*].schema..properties[*]~
    then:
      function: "pattern"
      functionOptions:
        match: "^[A-Za-z0-9_$]+$"

  # Boolean fields MUST NOT allow null values
  pzu:general11:2025-json-boolean-no-null-oas30:
    description: "Boolean fields MUST NOT allow null values."
    message: "Boolean fields MUST NOT allow null values (nullable: true). \n https://api-guidelines.app.pzu.pl/general-guidelines/#json-pzugeneral112025-json"
    severity: "error"
    given:
      - $.components..properties[?(@ && @.type && @.type=='boolean')]
      - $.paths[*][*]..[?(@ && @.type=='boolean')]
      - $.components[*][*]..[?(@ && @.type=='boolean')]
    then:
      field: nullable
      function: falsy

  pzu:general11:2025-json-boolean-no-null-oas31:
    description: "Boolean fields MUST NOT allow null values."
    message: "Boolean fields MUST NOT allow null values (type: [boolean, null]). \n https://api-guidelines.app.pzu.pl/general-guidelines/#json-pzugeneral112025-json"
    severity: "error"
    given:
      # @ && @.type && @.type.constructor && @.type.constructor.name=='Array' checking if every element in path exist and finally if given value is Array if so checking if it contains boolean -> type: [boolean, null]
      - $.components..properties[?(@ && @.type=='boolean' || (@ && @.type && @.type.constructor && @.type.constructor.name=='Array' && @.type.indexOf('boolean') != -1))]
      - $.paths[*][*]..[?(@ && @.type=='boolean' || (@ && @.type && @.type.constructor && @.type.constructor.name=='Array' && @.type.indexOf('boolean') != -1))]
      - $.components[*][*]..[?(@ && @.type=='boolean' || (@ && @.type && @.type.constructor && @.type.constructor.name=='Array' && @.type.indexOf('boolean') != -1))]
    then:
      function: disallowedNullInTypeArray

  # Empty arrays and objects MUST NOT be null (use [] or {} instead of null)
  pzu:general11:2025-json-no-null-arrays-or-objects:
    description: "Empty arrays and objects MUST NOT be null. Use [] or {} instead of null for empty collections."
    message: "Arrays and objects MUST NOT be null; use [] or {} instead. \n https://api-guidelines.app.pzu.pl/general-guidelines/#json-pzugeneral112025-json"
    severity: "error"
    given:
      - $.components..properties[?(
        (@ && @.type && (@.type=='array' || @.type=='object')) ||
        (@ && @.type && @.type.constructor && @.type.constructor.name=='Array' && (@.type.indexOf('array') != -1 || @.type.indexOf('object') != -1))
        )]
      - $.paths[*][*]..[?(
        (@ && @.type && (@.type=='array' || @.type=='object')) ||
        (@ && @.type && @.type.constructor && @.type.constructor.name=='Array' && (@.type.indexOf('array') != -1 || @.type.indexOf('object') != -1))
        )]
      - $.components[*][*]..[?(
        (@ && @.type && (@.type=='array' || @.type=='object')) ||
        (@ && @.type && @.type.constructor && @.type.constructor.name=='Array' && (@.type.indexOf('array') != -1 || @.type.indexOf('object') != -1))
        )]
    then:
      function: disallowedNullInTypeArrayAndObjects

  # Fields with a null value SHOULD be omitted
  pzu:general11:2025-json-null-fields-omitted:
    description: "Fields with a null value SHOULD be omitted from the payload."
    message: "'null' fields SHOULD be omitted from the payload. \n https://api-guidelines.app.pzu.pl/general-guidelines/#json-pzugeneral112025-json"
    severity: "warn"
    given:
      - $.components.examples[*].value..
      - $.components.examples[*]
      - $.paths[*][*]..example
      - $.paths[*][*]..examples
    then:
      - function: "schema"
        functionOptions:
          schema:
            not:
              type: "null"
      - function: "pattern"
        functionOptions:
          notMatch: "^null$"

  # Array property names SHOULD be plural (end with 's')
  pzu:general11:2025-json-array-property-plural:
    description: "Property names for fields that are arrays SHOULD be in plural form (e.g., `orders`: [])."
    message: "{{error}}"
    severity: "warn"
    given:
      - $.components..properties[?(@ && @.type=='array' || (@ && @.type && @.type.indexOf && @.type.indexOf('array') != -1 ) )]~
      - $.paths[*][*]..properties[?(@ && @.type=='array' || (@ && @.type && @.type.indexOf && @.type.indexOf('array') != -1 ) )]~
      - $.paths[*][*].parameters[?(@ && @.schema && @.schema.type=='array' || (@ && @.schema && @.schema.type && @.schema.type.indexOf && @.schema.type.indexOf('array') != -1 ) )].name
    then:
      function: checkTableNamePlural

  # URI naming conventions: kebab-case, no trailing slash
  pzu:rest6:2025-uri-naming-conventions:
    description: "Every URI MUST follow the General Naming Conventions, except for camelCase. Instead, hyphens (-) (kebab-case) MUST be used to separate compound words. Additionally, the URI MUST NOT end with a slash (/)."
    message: "URI path '{{property}}' MUST use kebab-case and MUST NOT end with a slash (/). \n https://api-guidelines.app.pzu.pl/rest/#uri-pzurest62025-uri-naming-conventions"
    severity: "error"
    given: "$.paths[*]~"
    then:
      - function: "pattern"
        functionOptions:
          # kebab-case, no trailing slash, starts with /, camel-case allowed in {} segments
          match: "^(/[a-z0-9]+(-[a-z0-9]+)*|/{[a-zA-Z][a-zA-Z0-9-]*})+$"
      - function: "pattern"
        functionOptions:
          # must not end with /
          notMatch: "/$"

  # URI template variable names MUST conform to RFC6570: only ALPHA, DIGIT, underscore (_) or percent-encoded characters are allowed.
  # NOTE: According to RFC6570, hyphen (-) is NOT allowed in URI template variable names.
  pzu:rest8:2025-path-params-naming-convention:
    description: >
      URI template variable names (inside curly braces, e.g., {variable}) MUST conform to RFC6570. 
      Variable names may only contain ALPHA, DIGIT, underscore (_) or percent-encoded characters. 
      NOTE: According to RFC6570, hyphen (-) is NOT allowed in URI template variable names.
    message: >
      "URI template variable name '{{property}}' must only use letters, digits, underscore (_), or percent-encoded characters. Hyphens (-) are NOT allowed (RFC6570).
      https://api-guidelines.app.pzu.pl/rest/#zmienne-szablonu-uri-pzurest82025-path-params-naming-conventions"
    severity: "error"
    given:
      - $.paths[*]~
    then:
      function: validatePathParamsNaming

  pzu:rest10:2025-headers-naming-conventions:
    description: "All HTTP headers MUST use Hyphenated-Pascal-Case notation"
    message: "HTTP headers MUST use Hyphenated-Pascal-Case \n https://api-guidelines.app.pzu.pl/rest/#nagowki-http-pzurest102025-headers-naming-conventions"
    severity: "error"
    given:
      - "$..parameters[?(@.in == 'header')].name"
      - "$.components.headers.*~"
      - "$.paths[*][*]..headers.*~"
    then:
      - function: "pattern"
        functionOptions:
          match: "^(X-[A-Z][a-z0-9]*(-[A-Z][a-z0-9]*)*|[A-Z][a-z0-9]*(-[A-Z][a-z0-9]*)*)$"

  pzu:rest10:2025-headers-naming-conventions-x-prefix:
    description: "HTTP headers SHOULD NOT include the 'X-' prefix."
    message: "HTTP headers SHOULD NOT include 'X-' prefix. \n https://api-guidelines.app.pzu.pl/rest/#nagowki-http-pzurest102025-headers-naming-conventions"
    severity: "warn"
    given:
      - "$..parameters[?(@.in == 'header')].name"
      - "$.components.headers.*~"
      - "$.paths[*][*]..headers.*~"
    then:
      function: "pattern"
      functionOptions:
        notMatch: "^[Xx]-"

  pzu:rest12:2025-resource-name-summary-required:
    description: "Each resource (endpoint) MUST have a name defined in the 'summary' field."
    message: "Resource '{{path}}' MUST have a 'summary' field. \n https://api-guidelines.app.pzu.pl/rest/#nazwa-zasobu-pzurest122025-resource-name"
    severity: "error"
    given: "$.paths[*]"
    then:
      field: summary
      function: truthy

  pzu:rest12:2025-resource-name-summary-format:
    description: "Each resource (endpoint) 'summary' field MUST start with capital letter, with words separated by spaces."
    message: "Resource 'summary' field MUST start with capital letter, with words separated by spaces. \n https://api-guidelines.app.pzu.pl/rest/#nazwa-zasobu-pzurest122025-resource-name"
    severity: "error"
    given: "$.paths[*]"
    then:
      field: summary
      function: "pattern"
      functionOptions:
        match: "^[A-Z].*$"

  pzu:rest12:2025-resource-name-summary-length:
    description: "Each resource (endpoint) 'summary' MUST have maximum 75 signs."
    message: "Resource 'summary' field MUST have maximum 75 signs. \n https://api-guidelines.app.pzu.pl/rest/#nazwa-zasobu-pzurest122025-resource-name"
    severity: "error"
    given: "$.paths[*]"
    then:
      field: summary
      function: "length"
      functionOptions:
        max: 75

  pzu:rest13:2025-operation-name-required:
    description: "Each operation (action) MUST have a name defined in the 'summary' field."
    message: "Operation MUST have a 'summary' field. \n https://api-guidelines.app.pzu.pl/rest/#nazwa-operacji-pzurest132025-operation-name`"
    severity: "error"
    given: "$.paths[*][?(@property == 'get' || @property == 'post' || @property == 'put' || @property == 'patch' || @property == 'delete' || @property == 'head' || @property == 'options' || @property == 'trace')]"
    then:
      field: summary
      function: truthy

  pzu:rest13:2025-operation-name-format:
    description: "Each operation (action) 'summary' field MUST start with capital letter, with words separated by spaces."
    message: "Operation 'summary' field MUST start with capital letter, with words separated by spaces. \n https://api-guidelines.app.pzu.pl/rest/#nazwa-zasobu-pzurest122025-resource-name"
    severity: "error"
    given: "$.paths[*][?(@property == 'get' || @property == 'post' || @property == 'put' || @property == 'patch' || @property == 'delete' || @property == 'head' || @property == 'options' || @property == 'trace')]"
    then:
      field: summary
      function: "pattern"
      functionOptions:
        match: "^[A-Z].*$"

  pzu:rest13:2025-operation-name-length:
    description: "Each operation (action) 'summary' MUST have maximum 75 signs."
    message: "Operation 'summary' field MUST have maximum 75 signs. \n https://api-guidelines.app.pzu.pl/rest/#nazwa-zasobu-pzurest122025-resource-name"
    severity: "error"
    given: "$.paths[*][?(@property == 'get' || @property == 'post' || @property == 'put' || @property == 'patch' || @property == 'delete' || @property == 'head' || @property == 'options' || @property == 'trace')]"
    then:
      field: summary
      function: "length"
      functionOptions:
        max: 75

  pzu:rest14:2025-operation-description-required:
    description: "Each operation (action) SHOULD have a description (defined in the 'description' field)."
    message: "Operation SHOULD have a 'description' field. \n https://api-guidelines.app.pzu.pl/rest/#opis-operacji-pzurest142025-operation-description"
    severity: "warn"
    given: "$.paths[*][?(@property == 'get' || @property == 'post' || @property == 'put' || @property == 'patch' || @property == 'delete' || @property == 'head' || @property == 'options' || @property == 'trace')]"
    then:
      field: description
      function: truthy

  pzu:rest14:2025-operation-description-length:
    description: "Each operation (action) description SHOULD be at least 30 characters long."
    message: "Operation 'description' SHOULD have at least 30 characters. \n https://api-guidelines.app.pzu.pl/rest/#opis-operacji-pzurest142025-operation-description"
    severity: "warn"
    given: "$.paths[*][?(@property == 'get' || @property == 'post' || @property == 'put' || @property == 'patch' || @property == 'delete' || @property == 'head' || @property == 'options' || @property == 'trace')]"
    then:
      field: description
      function: length
      functionOptions:
        min: 30

  # APIs using the HTTP protocol MUST use HTTPS
  pzu:rest17:2025-https-required:
    description: "APIs using the HTTP protocol MUST use HTTPS. All server URLs MUST begin with 'https://'."
    message: "server.url MUST use HTTPS. \n https://api-guidelines.app.pzu.pl/rest/#https-pzurest172025-https`"
    severity: "error"
    given: "$.servers[*].url"
    then:
      function: "pattern"
      functionOptions:
        match: "^https://"

  # Each API MUST use only valid HTTP methods for each operation.
  pzu:rest19:2025-request-methods:
    description: "Each API MUST use only valid HTTP methods for each operation. Only the following HTTP methods are allowed: GET, HEAD, PUT, PATCH, POST, TRACE, OPTIONS, DELETE."
    message: "Invalid HTTP method '{{property}}' found. Only GET, HEAD, PUT, PATCH, POST, TRACE, OPTIONS, DELETE are allowed as operation keys. \n https://api-guidelines.app.pzu.pl/rest/#metody-zapytan-pzurest192025-request-methods"
    severity: "error"
    given: "$.paths[*][*]~"
    then:
      function: "pattern"
      functionOptions:
        match: "^(get|head|put|patch|post|trace|options|delete|parameters|summary|description|$ref|servers)$"

  # Each API MUST use only valid HTTP status codes to communicate the result of a request operation.
  pzu:rest23:2025-status-codes:
    description: >
      Each API MUST use only valid HTTP status codes to communicate the result of a request operation.
      Only standard status codes or the "default" key are allowed in responses.
    message: "Invalid HTTP status code '{{property}}' found in responses. Only standard codes (except custom and WebDAV codes) or 'default' are allowed. \n https://api-guidelines.app.pzu.pl/rest/#kody-statusu-odpowiedzi-ang-response-status-codes-pzurest232025-status-codes"
    severity: "error"
    given: "$.paths[*].[get,post,put,patch,delete,head,options,trace].responses[*]~"
    then:
      function: "pattern"
      functionOptions:
        match: "^(default|10[0-3]|20[0-6]|208|226|30[0-5]|307|308|40[0-9]|41[0,3,5-7]|421|428|429|431|451|50[0-8]|510|511)$"

  # Error responses MUST define the 'content' property to communicate error details
  pzu:rest23:2025-separation-of-concerns:
    description: "Error responses (status codes 400–599) MUST define the 'content' property to communicate error details in API responses."
    message: "Error response MUST define the content property. \n https://api-guidelines.app.pzu.pl/rest/#separacja-zagadnien-pzurest182025-separation-of-concerns"
    severity: "error"
    given: "$.paths[*].[get,post,put,patch,delete,head,options,trace].responses[?(@property >= 400 && @property <= 599)]"
    then:
      field: content
      function: truthy

  # Each application/problem+json response MUST contain 'type', 'title' and 'detail' fields
  pzu:rest25:2025-problem-detail-fields-required:
    description: "Each response with the 'application/problem+json' media type MUST include the 'type', 'title' and 'detail' fields as required properties."
    message: "Error response (problem-detail) MUST define 'type', 'title' and 'detail' fields in its schema. \n https://api-guidelines.app.pzu.pl/rest/#format-odpowiedzi-na-bad-pzurest252025-problem-detail"
    severity: "error"
    given: "$.paths[*].[get,post,put,patch,delete,head,options,trace].responses[?(@property >= 400 && @property <= 599)].content['application/problem+json'].schema"
    then:
      function: schema
      functionOptions:
        schema:
          type: object
          properties:
            properties:
              type: object
              required:
                - type
                - title
                - detail
          required:
            - properties

  # application/problem+json 'type' property MUST be a string with URI format
  pzu:rest25:2025-problem-detail-type-format:
    description: "The 'type' property in 'application/problem+json' response body MUST be a string with uri format."
    message: "'type' property in application/problem+json response body MUST be a string with uri format. \n https://api-guidelines.app.pzu.pl/rest/#format-odpowiedzi-na-bad-pzurest252025-problem-detail"
    severity: "error"
    given: "$.paths[*].[get,post,put,patch,delete,head,options,trace].responses[?(@property >= 400 && @property <= 599)].content['application/problem+json'].schema"
    then:
      function: schema
      functionOptions:
        schema:
          type: object
          properties:
            properties:
              type: object
              properties:
                type:
                  type: object
                  properties:
                    type: { const: "string" }
                    format: { const: "uri" }
                  required:
                    - type
                    - format
          required:
            - properties

  # application/problem+json 'title' property MUST be a string
  pzu:rest25:2025-problem-detail-title-format:
    description: "The 'title' property in 'application/problem+json' response body MUST be a string."
    message: "'title' property in application/problem+json response body MUST be a string. \n https://api-guidelines.app.pzu.pl/rest/#format-odpowiedzi-na-bad-pzurest252025-problem-detail"
    severity: "error"
    given: "$.paths[*].[get,post,put,patch,delete,head,options,trace].responses[?(@property >= 400 && @property <= 599)].content['application/problem+json'].schema"
    then:
      function: schema
      functionOptions:
        schema:
          type: object
          properties:
            properties:
              type: object
              properties:
                title:
                  type: object
                  properties:
                    type: { const: "string" }
                  required:
                    - type
          required:
            - properties

  # application/problem+json 'detail' property MUST be a string
  pzu:rest25:2025-problem-detail-detail-format:
    description: "The 'detail' property in 'application/problem+json' response body MUST be a string."
    message: "'detail' property in application/problem+json response body MUST be a string. \n https://api-guidelines.app.pzu.pl/rest/#format-odpowiedzi-na-bad-pzurest252025-problem-detail"
    severity: "error"
    given: "$.paths[*].[get,post,put,patch,delete,head,options,trace].responses[?(@property >= 400 && @property <= 599)].content['application/problem+json'].schema"
    then:
      function: schema
      functionOptions:
        schema:
          type: object
          properties:
            properties:
              type: object
              properties:
                detail:
                  type: object
                  properties:
                    type: { const: "string" }
                  required:
                    - type
          required:
            - properties

  # Error responses MUST use application/problem+json (Problem Detail) format
  pzu:rest25:2025-problem-detail:
    description: "MUST use Problem Detail (application/problem+json) format to communicate error details in API responses."
    message: "MUST use Problem Detail (application/problem+json) format to communicate error details in API responses. \n https://api-guidelines.app.pzu.pl/rest/#format-odpowiedzi-na-bad-pzurest252025-problem-detail"
    severity: "error"
    given: "$.paths[*].[get,post,put,patch,delete,head,options,trace].responses[?(@property >= 400 && @property <= 599)].content"
    then:
      field: "application/problem+json"
      function: truthy

  # Problem Detail MUST NOT be used with 2xx responses
  pzu:rest25:2025-problem-detail-not-2xx:
    description: "MUST NOT use Problem Detail (application/problem+json) format for successful API (status codes 1xx,2xx and 3xx)."
    message: "MUST NOT use Problem Detail (application/problem+json) format for successful API (status codes 1xx,2xx and 3xx). \n https://api-guidelines.app.pzu.pl/rest/#format-odpowiedzi-na-bad-pzurest252025-problem-detail"
    severity: "error"
    given: "$.paths[*].[get,post,put,patch,delete,head,options,trace].responses[?(@property >= 100 && @property < 400)].content"
    then:
      field: "application/problem+json"
      function: falsy

  # application/problem+json MAY include 'instance' (URI of the resource) field
  pzu:rest25:2025-problem-detail-instance-optional:
    description: "Each response with the 'application/problem+json' media type MAY include the 'instance' field (a URI reference to the resource)."
    message: "MAY include the optional 'instance' (URI of the resource) field for error responses \n https://api-guidelines.app.pzu.pl/rest/#format-odpowiedzi-na-bad-pzurest252025-problem-detail"
    severity: "info"
    given: "$.paths[*].[get,post,put,patch,delete,head,options,trace].responses[?(@property >= 400 && @property <= 599)].content['application/problem+json'].schema"
    then:
      function: schema
      functionOptions:
        schema:
          type: object
          properties:
            properties:
              type: object
              required:
                - instance
          required:
            - properties

  # application/problem+json MAY include 'status' (the HTTP error status code) field
  pzu:rest25:2025-problem-detail-status-optional:
    description: "Each response with the 'application/problem+json' media type MAY include the 'status' field (the HTTP error status code)."
    message: "MAY include the optional 'status' of type integer (the HTTP error status code) field for error responses \n https://api-guidelines.app.pzu.pl/rest/#format-odpowiedzi-na-bad-pzurest252025-problem-detail"
    severity: "info"
    given: "$.paths[*].[get,post,put,patch,delete,head,options,trace].responses[?(@property >= 400 && @property <= 599)].content['application/problem+json'].schema"
    then:
      function: schema
      functionOptions:
        schema:
          type: object
          properties:
            properties:
              type: object
              required:
                - status
          required:
            - properties

  # application/problem+json 'instance' property, if present, MUST be a string with URI format
  pzu:rest25:2025-problem-detail-instance-format:
    description: "The 'instance' property in 'application/problem+json' response body MUST be a string with uri format."
    message: "'instance' property in application/problem+json response body MUST be a string with uri format. \n https://api-guidelines.app.pzu.pl/rest/#format-odpowiedzi-na-bad-pzurest252025-problem-detail"
    severity: "error"
    given: "$.paths[*].[get,post,put,patch,delete,head,options,trace].responses[?(@property >= 400 && @property <= 599)].content['application/problem+json'].schema"
    then:
      function: schema
      functionOptions:
        schema:
          type: object
          properties:
            properties:
              type: object
              properties:
                instance:
                  type: object
                  properties:
                    type: { const: "string" }
                    format: { const: "uri" }
                  required:
                    - type
                    - format
          required:
            - properties

  # application/problem+json 'status' property, if present, MUST be an integer and a valid HTTP status code (100-599)
  pzu:rest25:2025-problem-detail-status-format:
    description: "'status' property in application/problem+json response body MUST be an integer and be a valid HTTP status code (400-599)."
    message: "'status' property in application/problem+json response body MUST be an integer and be a valid HTTP status code (400-599). \n https://api-guidelines.app.pzu.pl/rest/#format-odpowiedzi-na-bad-pzurest252025-problem-detail"
    severity: "error"
    given: "$.paths[*].[get,post,put,patch,delete,head,options,trace].responses[?(@property >= 400 && @property <= 599)].content['application/problem+json'].schema"
    then:
      function: schema
      functionOptions:
        schema:
          type: object
          properties:
            properties:
              type: object
              properties:
                status:
                  type: object
                  properties:
                    type: { const: "integer" }
                    minimum: { const: 400 }
                    maximum: { const: 599 }
                  required:
                    - type
                    - minimum
                    - maximum
          required:
            - properties
  



checkTableNamePlural.js
export default function checkTableNamePlural(input, options, context) {
  const errors = [];
  
  if (!isPlural(input)) {
    errors.push({
      message: `Array collection property '${input}' SHOULD be plural. https://api-guidelines.app.pzu.pl/general-guidelines/#json-pzugeneral112025-json`,
      path: context.path
    });
  }
  return errors;
}

function isPlural(word) {
  if (!word || typeof word !== 'string') return false;

  const irregularPlurals = {
    'child': 'children',
    'foot': 'feet', 
    'tooth': 'teeth',
    'mouse': 'mice',
    'person': 'people',
    'man': 'men',
    'woman': 'women'
  };
  const lowerWord = word.toLowerCase();
  // Check irregular plurals
  if (Object.values(irregularPlurals).includes(lowerWord)) {
    return true;
  }
  // Check common plural patterns
  return (
    lowerWord.endsWith('s') && !lowerWord.endsWith('ss') ||
    lowerWord.endsWith('es') ||
    lowerWord.endsWith('ies') ||
    lowerWord.endsWith('ves') ||
    lowerWord.endsWith('en') && lowerWord !== 'open'
  );
}

disallowedNullInTypeArray.js
export default function (targetVal, _options = undefined, context) {
  if (!targetVal || typeof targetVal !== 'object') {
    return [];
  }
  const { type } = targetVal;
  const [ typeDef ] = type;
  if (Array.isArray(type) && (type.includes('null') || type.includes(null))) {
    return [
      {
        message: `Property at path '${context.path.join('.')}' is a ${typeDef} but includes 'null' in its type array: [${type.join(', ')}]. This is disallowed.`,
        path: context.path
      },
    ];
  }

  return [];
}

disallowedNullInTypeArrayAndObjects.js
function testType(type, context) {
  if (Array.isArray(type)) {
    if (type.includes('null') || type.includes(null)) {
      return [
        {
          message: `Property at path '${context.path.join('.')}' includes 'null' in its type array: []. This is disallowed.`,
          path: context.path
        },
      ];
    }
  }

  if (typeof type === 'string' && type === 'null') {
    return [
      {
        message: `Property at path '${context.path.join('.')}' includes 'null' in its type array: []. This is disallowed.`,
        path: context.path
      },
    ];
  }

  if (typeof type === 'object' && type === null) {
    return [
      {
        message: `Property at path '${context.path.join('.')}' includes 'null' in its type array: []. This is disallowed.`,
        path: context.path
      },
    ];
  }
  
}

export default function (targetVal, _options = undefined, context) {
  if (!targetVal || typeof targetVal !== 'object') {
    return [];
  }

  let result;
  const { type } = targetVal;

  result = testType(type, context);

  if (targetVal.items) {
    const itemsType = targetVal.items.type;
    result = testType(itemsType, context);
  }

  if (targetVal.properties) {
    Object.entries(targetVal.properties).forEach(([key, value]) => {
      if (value.type) {
        result = testType(value.type, context);
      }
    })
    result = [];
  }

  return result;
}


logAndHelp.js
export default function (targetVal, _options = undefined, context) {
  console.log('helpFunction!!!!', targetVal);

  return [];
}

validatePathParameter.js

export default function (targetVal, opts, context) {
  if (typeof targetVal !== 'string') return [];
  // Extract all {variable} segments
  const matches = targetVal.match(/\{([^}]+)\}/g);
  if (!matches) return;
  const errors = [];
  for (const match of matches) {
    const varName = match.slice(1, -1); // remove {}
    // Only allow ALPHA, DIGIT, underscore, percent-encoded
    if (!/^[A-Za-z0-9_]+(?:%[A-Fa-f0-9]{2})*$/.test(varName)) {
      errors.push({
        message: `URI template variable name '${varName}' must only use letters, digits, underscore (_), or percent-encoded characters. Hyphens (-) are NOT allowed (RFC6570).`,
        path: context.path,
      });
    }
  }
  return errors.length ? errors : [];
};

