// Configuracao do Node-RED do projeto (uso local / laboratorio)
module.exports = {
  uiPort: process.env.PORT || 1880,
  flowFile: 'flows.json',
  credentialSecret: false,          // credenciais em texto no flows_cred.json (apenas uso local)
  flowFilePretty: true,
  functionExternalModules: false,
  functionTimeout: 0,
  logging: { console: { level: 'info', metrics: false, audit: false } },
  editorTheme: { projects: { enabled: false } },
  contextStorage: { default: { module: 'memory' } }
};
