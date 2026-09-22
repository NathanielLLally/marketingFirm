-- schema_dump.sql
-- Usage: psql -d mydb -f schema_dump.sql
--    or: psql -d mydb -c "\i schema_dump.sql"
--    or from within psql: \i schema_dump.sql

\pset format wrapped
\pset columns 0
\pset linestyle unicode
\pset border 1
\pset null '∅'
\timing off

-- ────────────────────────────────────────────────────────────────
-- 1. SCHEMAS
-- ────────────────────────────────────────────────────────────────
\echo ''
\echo '════════════════════════════════════════════════════════════'
\echo ' SCHEMAS'
\echo '════════════════════════════════════════════════════════════'

SELECT
    n.nspname                            AS schema,
    pg_catalog.pg_get_userbyid(n.nspowner) AS owner,
    obj_description(n.oid, 'pg_namespace') AS comment
FROM pg_catalog.pg_namespace n
WHERE n.nspname !~ '^pg_'
  AND n.nspname <> 'information_schema'
ORDER BY schema;

-- ────────────────────────────────────────────────────────────────
-- 2. TABLES
-- ────────────────────────────────────────────────────────────────
\echo ''
\echo '════════════════════════════════════════════════════════════'
\echo ' TABLES'
\echo '════════════════════════════════════════════════════════════'

SELECT
    t.table_schema                         AS schema,
    t.table_name                           AS table,
    t.table_type,
    pg_size_pretty(
        pg_total_relation_size(
            (quote_ident(t.table_schema) || '.' || quote_ident(t.table_name))::regclass
        )
    )                                      AS total_size,
    c.reltuples::bigint                    AS est_rows,
    obj_description(c.oid, 'pg_class')     AS comment
FROM information_schema.tables t
JOIN pg_catalog.pg_class c
  ON c.relname = t.table_name
JOIN pg_catalog.pg_namespace n
  ON n.oid = c.relnamespace
 AND n.nspname = t.table_schema
WHERE t.table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema, table;

-- ────────────────────────────────────────────────────────────────
-- 3. COLUMNS
-- ────────────────────────────────────────────────────────────────
\echo ''
\echo '════════════════════════════════════════════════════════════'
\echo ' COLUMNS'
\echo '════════════════════════════════════════════════════════════'

SELECT
    c.table_schema                         AS schema,
    c.table_name                           AS table,
    c.ordinal_position                     AS "#",
    c.column_name                          AS column,
    c.data_type
        || CASE
             WHEN c.character_maximum_length IS NOT NULL
             THEN '(' || c.character_maximum_length || ')'
             WHEN c.numeric_precision IS NOT NULL AND c.data_type IN ('numeric','decimal')
             THEN '(' || c.numeric_precision || ',' || c.numeric_scale || ')'
             ELSE ''
           END                             AS type,
    CASE c.is_nullable WHEN 'NO' THEN 'NOT NULL' ELSE '' END AS nullable,
    c.column_default                       AS default,
    pg_catalog.col_description(
        (quote_ident(c.table_schema) || '.' || quote_ident(c.table_name))::regclass::oid,
        c.ordinal_position
    )                                      AS comment
FROM information_schema.columns c
WHERE c.table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema, table, "#";

-- ────────────────────────────────────────────────────────────────
-- 4. PRIMARY KEYS & UNIQUE CONSTRAINTS
-- ────────────────────────────────────────────────────────────────
\echo ''
\echo '════════════════════════════════════════════════════════════'
\echo ' PRIMARY KEYS & UNIQUE CONSTRAINTS'
\echo '════════════════════════════════════════════════════════════'

SELECT
    n.nspname                              AS schema,
    t.relname                              AS table,
    c.conname                              AS constraint,
    c.contype::text                        AS type,  -- p=PK, u=unique
    pg_get_constraintdef(c.oid, true)      AS definition
FROM pg_catalog.pg_constraint c
JOIN pg_catalog.pg_class t     ON t.oid = c.conrelid
JOIN pg_catalog.pg_namespace n ON n.oid = t.relnamespace
WHERE c.contype IN ('p', 'u')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema, table, type, constraint;

-- ────────────────────────────────────────────────────────────────
-- 5. FOREIGN KEYS
-- ────────────────────────────────────────────────────────────────
\echo ''
\echo '════════════════════════════════════════════════════════════'
\echo ' FOREIGN KEYS'
\echo '════════════════════════════════════════════════════════════'

SELECT
    n.nspname                              AS schema,
    t.relname                              AS table,
    c.conname                              AS constraint,
    pg_get_constraintdef(c.oid, true)      AS definition,
    CASE c.confupdtype
        WHEN 'a' THEN 'NO ACTION'
        WHEN 'r' THEN 'RESTRICT'
        WHEN 'c' THEN 'CASCADE'
        WHEN 'n' THEN 'SET NULL'
        WHEN 'd' THEN 'SET DEFAULT'
    END                                    AS on_update,
    CASE c.confdeltype
        WHEN 'a' THEN 'NO ACTION'
        WHEN 'r' THEN 'RESTRICT'
        WHEN 'c' THEN 'CASCADE'
        WHEN 'n' THEN 'SET NULL'
        WHEN 'd' THEN 'SET DEFAULT'
    END                                    AS on_delete
FROM pg_catalog.pg_constraint c
JOIN pg_catalog.pg_class t     ON t.oid = c.conrelid
JOIN pg_catalog.pg_namespace n ON n.oid = t.relnamespace
WHERE c.contype = 'f'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema, table, constraint;

-- ────────────────────────────────────────────────────────────────
-- 6. INDEXES
-- ────────────────────────────────────────────────────────────────
\echo ''
\echo '════════════════════════════════════════════════════════════'
\echo ' INDEXES'
\echo '════════════════════════════════════════════════════════════'

SELECT
    n.nspname                              AS schema,
    t.relname                              AS table,
    i.relname                              AS index,
    ix.indisunique                         AS unique,
    ix.indisprimary                        AS primary,
    am.amname                              AS method,
    pg_get_indexdef(ix.indexrelid, 0, true) AS definition,
    pg_size_pretty(pg_relation_size(i.oid)) AS index_size
FROM pg_catalog.pg_index ix
JOIN pg_catalog.pg_class t     ON t.oid = ix.indrelid
JOIN pg_catalog.pg_class i     ON i.oid = ix.indexrelid
JOIN pg_catalog.pg_namespace n ON n.oid = t.relnamespace
JOIN pg_catalog.pg_am am       ON am.oid = i.relam
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND t.relkind = 'r'
ORDER BY schema, table, index;

-- ────────────────────────────────────────────────────────────────
-- 7. VIEWS
-- ────────────────────────────────────────────────────────────────
\echo ''
\echo '════════════════════════════════════════════════════════════'
\echo ' VIEWS'
\echo '════════════════════════════════════════════════════════════'

SELECT
    n.nspname                              AS schema,
    c.relname                              AS view,
    CASE c.relkind
        WHEN 'v'  THEN 'VIEW'
        WHEN 'm'  THEN 'MATERIALIZED VIEW'
    END                                    AS kind,
    pg_get_viewdef(c.oid, true)            AS definition
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('v', 'm')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema, kind, view;

-- ────────────────────────────────────────────────────────────────
-- 8. SEQUENCES
-- ────────────────────────────────────────────────────────────────
\echo ''
\echo '════════════════════════════════════════════════════════════'
\echo ' SEQUENCES'
\echo '════════════════════════════════════════════════════════════'

SELECT
    sequence_schema                        AS schema,
    sequence_name                          AS sequence,
    data_type,
    start_value,
    minimum_value,
    maximum_value,
    increment,
    cycle_option
FROM information_schema.sequences
WHERE sequence_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema, sequence;

-- ────────────────────────────────────────────────────────────────
-- 9. FUNCTIONS & PROCEDURES
-- ────────────────────────────────────────────────────────────────
\echo ''
\echo '════════════════════════════════════════════════════════════'
\echo ' FUNCTIONS & PROCEDURES'
\echo '════════════════════════════════════════════════════════════'

SELECT
    n.nspname                              AS schema,
    p.proname                              AS name,
    CASE p.prokind
        WHEN 'f' THEN 'FUNCTION'
        WHEN 'p' THEN 'PROCEDURE'
        WHEN 'a' THEN 'AGGREGATE'
        WHEN 'w' THEN 'WINDOW'
    END                                    AS kind,
    pg_get_function_arguments(p.oid)       AS arguments,
    pg_get_function_result(p.oid)          AS returns,
    l.lanname                              AS language,
    obj_description(p.oid, 'pg_proc')      AS comment
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
JOIN pg_catalog.pg_language l  ON l.oid = p.prolang
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema, kind, name;

-- ────────────────────────────────────────────────────────────────
-- 10. TRIGGERS
-- ────────────────────────────────────────────────────────────────
\echo ''
\echo '════════════════════════════════════════════════════════════'
\echo ' TRIGGERS'
\echo '════════════════════════════════════════════════════════════'

SELECT
    n.nspname                              AS schema,
    t.relname                              AS table,
    tr.tgname                              AS trigger,
    CASE tr.tgtype & 2 WHEN 2 THEN 'BEFORE' ELSE 'AFTER' END AS timing,
    array_to_string(
        ARRAY[
            CASE WHEN tr.tgtype &  4 > 0 THEN 'INSERT'  END,
            CASE WHEN tr.tgtype &  8 > 0 THEN 'DELETE'  END,
            CASE WHEN tr.tgtype & 16 > 0 THEN 'UPDATE'  END,
            CASE WHEN tr.tgtype & 32 > 0 THEN 'TRUNCATE' END
        ],
        ' OR '
    )                                      AS events,
    CASE tr.tgtype & 1 WHEN 1 THEN 'ROW' ELSE 'STATEMENT' END AS level,
    p.proname                              AS function,
    tr.tgenabled                           AS enabled
FROM pg_catalog.pg_trigger tr
JOIN pg_catalog.pg_class t     ON t.oid = tr.tgrelid
JOIN pg_catalog.pg_namespace n ON n.oid = t.relnamespace
JOIN pg_catalog.pg_proc p      ON p.oid = tr.tgfoid
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND NOT tr.tgisinternal
ORDER BY schema, table, trigger;

-- ────────────────────────────────────────────────────────────────
-- 11. CHECK CONSTRAINTS
-- ────────────────────────────────────────────────────────────────
\echo ''
\echo '════════════════════════════════════════════════════════════'
\echo ' CHECK CONSTRAINTS'
\echo '════════════════════════════════════════════════════════════'

SELECT
    n.nspname                              AS schema,
    t.relname                              AS table,
    c.conname                              AS constraint,
    pg_get_constraintdef(c.oid, true)      AS definition
FROM pg_catalog.pg_constraint c
JOIN pg_catalog.pg_class t     ON t.oid = c.conrelid
JOIN pg_catalog.pg_namespace n ON n.oid = t.relnamespace
WHERE c.contype = 'c'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema, table, constraint;

-- ────────────────────────────────────────────────────────────────
-- 12. EXTENSIONS
-- ────────────────────────────────────────────────────────────────
\echo ''
\echo '════════════════════════════════════════════════════════════'
\echo ' EXTENSIONS'
\echo '════════════════════════════════════════════════════════════'

SELECT
    e.extname                              AS extension,
    e.extversion                           AS version,
    n.nspname                              AS schema,
    e.extrelocatable                       AS relocatable,
    c.description
FROM pg_catalog.pg_extension e
JOIN pg_catalog.pg_namespace n ON n.oid = e.extnamespace
LEFT JOIN pg_catalog.pg_description c
  ON c.objoid = e.oid
 AND c.classoid = 'pg_extension'::regclass
ORDER BY extension;

\echo ''
\echo '════════════════════════════════════════════════════════════'
\echo ' END OF SCHEMA REPORT'
\echo '════════════════════════════════════════════════════════════'
\echo ''
