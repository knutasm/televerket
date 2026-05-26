-- Staging model template for Televerket dbt project.
-- One CTE: selects from source and applies all transformations.
-- Final select reorders columns into the standard grouping.

with source as (
    select
        -- pure selects (no rename, no cast)
        <col>,

        -- name / type conversions (rename, cast, or both)
        <old_name> as <new_name>,
        <col>::date as <col>,
        try_cast(<col> as decimal(10, 2)) as <col>,
        {{ parse_yyyymmdd('<col>') }} as <col>,

        -- unpacking / other transforms (JSON, macros, expressions)
        {{ json_extract('<json_col>', '<field>') }} as <field>

    from {{ source("<schema>", "<table>") }}
)

select
    -- primary key
    <pk_col>,

    -- foreign keys
    <fk_col>,

    -- attributes — textual / categorical
    <text_col>,

    -- attributes — numerical
    <num_col>,

    -- flags
    <flag_col>,

    -- dates / times
    <date_col>,

    -- system columns
    <sys_col>

from source
