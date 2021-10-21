WITH cte_coluna AS (
    SELECT 
        coluna.owner,
        coluna.table_name,
        coluna.column_name,
        max(to_number(regexp_substr(indice.index_name, '([^_]*)$'))) as nu_identificador,
        RANK() OVER( PARTITION BY coluna.owner, coluna.table_name ORDER BY LENGTH(coluna.column_name), coluna.column_name ASC)  as nu_rank
    FROM (
        SELECT
            coluna.owner,
            coluna.table_name,
            restricao.constraint_name,
            LISTAGG(coluna.column_name, ',') WITHIN GROUP (ORDER BY coluna.position ASC) as column_name
        FROM
            all_constraints restricao
            INNER JOIN all_cons_columns  coluna ON restricao.owner = coluna.owner
                                                  AND restricao.table_name = coluna.table_name
                                                  AND restricao.constraint_name = coluna.constraint_name
        WHERE
            restricao.constraint_type = 'R'
        GROUP BY
            coluna.owner,
            coluna.table_name,
            restricao.constraint_name 
        ) coluna
        LEFT JOIN dba_indexes       indice ON indice.table_owner = coluna.owner
                                                  AND indice.table_name = coluna.table_name
                                                  AND regexp_substr(indice.index_name, '[^_]+', 1, 1) = 'IDX'
    WHERE
        NOT EXISTS (
            SELECT 
                1 
            FROM (
                SELECT
                    indice.table_owner,
                    indice.table_name,
                    indice.index_name,
                    LISTAGG(indice.column_name, ',') WITHIN GROUP (ORDER BY indice.column_position ASC) as column_name
                FROM
                    all_ind_columns indice
                GROUP BY
                    indice.table_owner,
                    indice.table_name,
                    indice.index_name
            ) indice
            WHERE
                indice.table_owner = coluna.owner
                AND indice.table_name = coluna.table_name
                AND indice.column_name = coluna.column_name
        )
    GROUP BY
        coluna.owner,
        coluna.table_name,
        coluna.column_name
)
SELECT 
    'CREATE INDEX ' || coluna.owner|| '.IDX_' || REPLACE(coluna.table_name, 'TB_', '') || '_' || 
        lpad( nvl( nu_identificador, 0 ) + nu_rank, 2, '0') || ' ON ' || coluna.owner || '.'|| coluna.table_name || ' ('|| coluna.column_name || 
        ' ASC) tablespace TBS_' || coluna.owner|| '_I;'
FROM 
    cte_coluna coluna
WHERE
    coluna.owner = :owner;
