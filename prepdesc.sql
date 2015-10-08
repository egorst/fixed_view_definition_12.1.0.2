set lines 100 pages 0 feedb off trims on
spool mkdesc.sql
select 'set lines 100 pages 0 feedb off trims on' from dual;
select 'spool fvdesc.txt' from dual;
select 'prompt +++'||view_name||'+++'||chr(10)||'desc '||view_name from v$fixed_view_definition order by view_name;
select 'spool off' from dual;
select 'exit' from dual;
spool off
exit
