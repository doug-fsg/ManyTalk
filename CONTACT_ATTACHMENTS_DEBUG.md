# 🔍 DEBUG: Anexos de Contatos - Falha ao Enviar Arquivo

## ✅ Correções Aplicadas

1. **Service de Upload** - Corrigido método `create_blob` para evitar problemas com checksum
2. **Controller** - Adicionados logs detalhados para debug
3. **API Client** - Adicionado tratamento de erros com console.log
4. **Componente Vue** - Adicionados logs detalhados no processo de upload

## 🔧 Como Debugar

### 1. Verificar Console do Navegador (DevTools)

Abra o DevTools (F12) e vá para a aba **Console**. Você verá:

```javascript
Files selected: 1 Contact ID: 123 Attribute: documento_rg
Starting upload...
Upload response: {...}
```

OU em caso de erro:

```javascript
Upload failed: Error: ...
Error response: {...}
Error status: 500
```

### 2. Verificar Logs do Rails

No terminal onde o Rails está rodando, você verá:

```ruby
Upload request - Contact: 123, Attribute: documento_rg, Files: 1
```

OU em caso de erro:

```ruby
File upload error: ArgumentError - File size exceeds limit
```

### 3. Verificar Network Tab

No DevTools, aba **Network**:

1. Clique em **Upload file**
2. Procure pela requisição `contact_attribute_files`
3. Veja:
   - **Headers**: URL, Method (POST), Status
   - **Payload**: FormData com `file` e `attribute_key`
   - **Response**: JSON com erro ou sucesso

## 🐛 Problemas Comuns e Soluções

### Problema 1: "No file provided"

**Sintoma:** Console mostra "No file provided in params"

**Causa:** Parâmetro do arquivo não está sendo enviado corretamente

**Solução:**
```javascript
// Verificar no console:
console.log('FormData keys:', Array.from(formData.keys()));
```

### Problema 2: "Failed to upload file: undefined method"

**Sintoma:** Erro no backend sobre método inexistente

**Causa:** Problema com Active Storage ou configuração de storage

**Solução:**
```bash
# Verificar configuração do Active Storage
rails active_storage:install
rails db:migrate
```

### Problema 3: Rota não encontrada (404)

**Sintoma:** Network tab mostra 404 Not Found

**Causa:** Rotas não foram recarregadas após mudança

**Solução:**
```bash
# Reiniciar o servidor Rails
# Ctrl+C e depois:
rails s
```

### Problema 4: CORS ou CSRF Token

**Sintoma:** 403 Forbidden ou erro de CSRF

**Solução:** Verificar se o token CSRF está sendo enviado nos headers

### Problema 5: Arquivo muito grande

**Sintoma:** "File size exceeds limit"

**Causa:** Arquivo maior que 10MB

**Solução:** Aumentar limite ou reduzir tamanho do arquivo

## 📊 Checklist de Verificação

- [ ] Servidor Rails está rodando
- [ ] Assets foram compilados (`yarn build` ou `rails assets:precompile`)
- [ ] Storage está configurado (verificar `config/storage.yml`)
- [ ] Active Storage está instalado
- [ ] Atributo personalizado tipo "File" foi criado
- [ ] `contactId` é válido e existe
- [ ] `attributeKey` corresponde ao atributo criado
- [ ] Arquivo tem menos de 10MB
- [ ] Console do navegador não mostra erros JS
- [ ] Logs do Rails não mostram erros

## 🚀 Teste Manual Rápido

### Via Console Rails:

```ruby
# No rails console
service = ContactAttributeFileUploadService.new(
  account: Account.first,
  contact: Contact.first,
  attribute_key: 'test_file'
)

# Simular upload (você precisa de um arquivo de teste)
file = File.open('/path/to/test.pdf')
uploaded_file = ActionDispatch::Http::UploadedFile.new(
  tempfile: file,
  filename: 'test.pdf',
  type: 'application/pdf'
)

result = service.upload(uploaded_file)
puts result.inspect
```

### Via CURL:

```bash
curl -X POST \
  http://localhost:3000/api/v1/accounts/1/contacts/1/contact_attribute_files \
  -H 'api_access_token: YOUR_TOKEN' \
  -F 'attribute_key=test_file' \
  -F 'file=@/path/to/test.pdf'
```

## 📝 Próximos Passos

1. Abra o console do navegador
2. Tente fazer upload de um arquivo
3. Copie TODOS os logs (console + network + rails logs)
4. Me envie os logs para análise detalhada

## 🔑 Informações Importantes a Coletar

- [ ] URL completa da requisição
- [ ] Status HTTP da resposta
- [ ] Conteúdo do erro (JSON)
- [ ] Logs do Rails (últimas 20 linhas)
- [ ] Tamanho do arquivo tentado
- [ ] Tipo do arquivo (PDF, imagem, etc)
- [ ] ID do contato
- [ ] Chave do atributo (attribute_key)

