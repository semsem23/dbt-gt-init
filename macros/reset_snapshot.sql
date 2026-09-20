{% macro reset_snapshot(snapshot_name='orders_snapshot') %}
{#
    Drops the given snapshot table so the next `dbt snapshot` treats it as a
    first-time run (plain CREATE TABLE) instead of a MERGE. Needed because
    this project's GCP project runs in BigQuery Sandbox mode (no billing
    account), which blocks the MERGE a snapshot normally uses to record
    changes on every run after the first. See snapshots/_snapshots.yml.

    Usage: dbt run-operation reset_snapshot
#}
{% if execute %}
    {% set relation = adapter.get_relation(
        database=target.database, schema='snapshots', identifier=snapshot_name
    ) %}
    {% if relation is not none %}
        {% do run_query('drop table if exists ' ~ relation) %}
        {{ log('Dropped ' ~ relation ~ ' so the next `dbt snapshot` recreates it fresh (Sandbox mode has no billing, so MERGE is blocked).', info=True) }}
    {% else %}
        {{ log(snapshot_name ~ ' does not exist yet — nothing to drop.', info=True) }}
    {% endif %}
{% endif %}
{% endmacro %}
