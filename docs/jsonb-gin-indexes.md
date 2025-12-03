# JSONB GIN Indexes no Serverpod

## Suporte Implementado

Este fork do Serverpod suporta totalmente índices JSONB GIN via definições YAML, incluindo:

- Índices GIN simples (operator class default `jsonb_ops`)
- Índices GIN com predicates para soft delete
- Expressões JSONB com btree para queries de igualdade
- Expressões JSONB com predicates

## Tipos de Índices Suportados

### 1. GIN Simples (jsonb_ops - default)

**YAML:**
```yaml
indexes:
  metadata_idx:
    fields: metadata
    type: gin
```

**SQL Gerado:**
```sql
CREATE INDEX "metadata_idx" ON "table" USING gin ("metadata");
```

**Uso:** Suporta todos os operadores JSONB: `@>`, `@?`, `@@`, `?`, `?&`, `?|`

### 2. GIN com Predicate (Soft Delete)

**YAML:**
```yaml
indexes:
  metadata_active_idx:
    fields: metadata
    type: gin
    predicate: "deletedAt IS NULL"
```

**SQL Gerado:**
```sql
CREATE INDEX "metadata_active_idx" ON "table" USING gin ("metadata")
WHERE "deletedAt" IS NULL;
```

**Uso:** Índice parcial que cobre apenas registros ativos, reduzindo tamanho e melhorando performance para queries que sempre filtram por `deletedAt IS NULL`.

### 3. Expressão JSONB (btree)

**YAML:**
```yaml
indexes:
  user_email_idx:
    fields: (profile->>'email')
    type: btree
```

**SQL Gerado:**
```sql
CREATE INDEX "user_email_idx" ON "table" USING btree ((profile->>'email'));
```

**Uso:** Bom para queries de igualdade exata (`=`) em valores extraídos de JSONB.

### 4. Expressão JSONB com Predicate

**YAML:**
```yaml
indexes:
  active_user_email_idx:
    fields: (profile->>'email')
    type: btree
    predicate: "deletedAt IS NULL"
```

**SQL Gerado:**
```sql
CREATE INDEX "active_user_email_idx" ON "table" USING btree ((profile->>'email'))
WHERE "deletedAt" IS NULL;
```

**Uso:** Combina extração de valor JSONB com índice parcial para máxima eficiência.

## Limitações Conhecidas

### ❌ Operator Class Explícito (`jsonb_path_ops`)

**NÃO SUPORTADO:**
```yaml
indexes:
  credentials_path_idx:
    fields: credentials jsonb_path_ops  # ❌ Validação rejeita
    type: gin
```

**Motivo:** O validador de campos do Serverpod (`restrictions.dart`) não reconhece operator classes como parte válida da definição de campo.

**Workaround:** Usar GIN simples (default `jsonb_ops`) que funciona perfeitamente para a maioria dos casos de uso.

**Status:** O gerador de SQL está preparado para operator classes, mas a validação precisa ser ajustada.

## Performance Tips

### GIN vs Expressão Btree

- **GIN**: Use para queries de containment (`@>`, `<@`, `?`, `?|`, `?&`)
  - Exemplo: `WHERE metadata @> '{"type": "premium"}'`

- **Expressão Btree**: Use para igualdade exata (`=`)
  - Exemplo: `WHERE metadata->>'email' = 'user@example.com'`

### Predicates e Soft Delete

**IMPORTANTE:** Predicates servem APENAS para reduzir tamanho do índice, NÃO para garantir unicidade!

✅ **CORRETO - Índice de busca com predicate:**
```yaml
indexes:
  metadata_search_idx:
    fields: metadata
    type: gin
    predicate: "deletedAt IS NULL"  # Performance: índice menor
```

❌ **ERRADO - Tentativa de unicidade com predicate:**
```yaml
indexes:
  email_unique:
    fields: email
    unique: true
    predicate: "deletedAt IS NULL"  # ❌ Predicate não afeta unicidade!
```

**Regra:**
- Índices de **UNICIDADE** (email, CPF): SEM predicate
- Índices de **BUSCA** (nome, metadata): COM predicate quando apropriado

## Exemplos Práticos

### Modelo de Integration com Credentials JSONB

```yaml
class: Integration
table: integration
fields:
  id: int?, !persist
  type: IntegrationType
  credentials: Jsonb
  metadata: Jsonb?
  deletedAt: DateTime?

indexes:
  # GIN para queries de containment em credentials
  integration_credentials_gin:
    fields: credentials
    type: gin
    predicate: "deletedAt IS NULL"

  # Btree para lookup específico por gymId
  integration_gymid_idx:
    fields: (credentials->>'gymId')
    type: btree
    predicate: "deletedAt IS NULL"

  # GIN para busca em metadata (nullable)
  integration_metadata_gin:
    fields: metadata
    type: gin
    predicate: "deletedAt IS NULL AND metadata IS NOT NULL"
```

### Queries Otimizadas

```dart
// Query usando índice GIN
await Integration.db.find(
  session,
  where: (t) =>
    t.credentials.jsonSupersetOf({'type': 'gympass'}) &
    t.deletedAt.isNull(),
);
// Usa: integration_credentials_gin

// Query usando índice btree de expressão
await Integration.db.findFirstRow(
  session,
  where: (t) =>
    t.credentials.jsonExtract('gymId').equals('12345') &
    t.deletedAt.isNull(),
);
// Usa: integration_gymid_idx
```

## Implementação Técnica

### Arquivos Modificados

1. **SQL Generation** - `tools/serverpod_cli/lib/src/database/extensions.dart`
   - Método: `IndexDefinitionPgSqlGeneration.toPgSql()`
   - Adicionado: Bloco condicional para processar índices GIN com operator classes

2. **Database Introspection** - `packages/serverpod/lib/src/database/analyze.dart`
   - Modificado: Lógica de reconhecimento de operator classes GIN
   - Adicionado: Listas de operator classes default vs explícitas

3. **Normalização** - `packages/serverpod_shared/lib/src/util.dart`
   - Função `normalizePredicate`: Adicionada normalização de expressões JSONB
   - Função `normalizeIndexDefinition`: Nova função para normalizar elementos de índice
   - Correções: Remoção de casting `::text`, normalização de espaços, predicates compostos

### Validação de Schema

O sistema de introspection foi aprimorado para:

- Reconhecer diferenças de formatação do PostgreSQL (casting `::text`, espaços extras)
- Normalizar predicates compostos
- Comparar corretamente expressões JSONB
- Evitar falsos positivos em schema mismatch

## Referências

- [PostgreSQL JSONB Indexing](https://www.postgresql.org/docs/current/datatype-json.html#JSON-INDEXING)
- [GIN Operator Classes](https://www.postgresql.org/docs/current/gin-builtin-opclasses.html)
- [Serverpod Documentation](https://docs.serverpod.dev/)
