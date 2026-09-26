/* =============================================================================
   LAB 00  |  Version and release-update check
   -----------------------------------------------------------------------------
   Purpose   : Prove the instance is Oracle AI Database 26ai (release 23.26.x)
               and show which release update is installed.
   Run as    : SYS (AS SYSDBA), connected to the PDB
   Requires  : Nothing
   Article   : "26ai replaces 23ai via a release update, not an upgrade"
   Output    : ../sample_output/00_version_check.md
   ============================================================================= */

SET DEFINE OFF
SET LINESIZE 200
SET PAGESIZE 100
SET TIMING ON
COLUMN banner_full  FORMAT A90
COLUMN description  FORMAT A62
COLUMN action_time  FORMAT A32

PROMPT
PROMPT === 0.1  Version banner (expect: "Oracle AI Database 26ai ... 23.26.x") ===
SELECT banner_full FROM v$version;

PROMPT
PROMPT === 0.2  Numeric version (VERSION stays 23.0.0.0.0, VERSION_FULL = 23.26.x) ===
SELECT version, version_full FROM v$instance;

PROMPT
PROMPT === 0.3  COMPATIBLE parameter ===
-- NOTE: on the reference system this was 23.6.0 (not 23.0.0). Either way it is a
-- 23.x value, i.e. 26ai keeps the 23ai compatibility family - no new major version.
SHOW PARAMETER compatible

PROMPT
PROMPT === 0.4  Installed release update(s) ===
SELECT patch_id, action, status, description, action_time
FROM   dba_registry_sqlpatch
ORDER  BY action_time;

PROMPT
PROMPT === 0.5  Feature-usage record for vector features (optional) ===
-- Returns "no rows selected" until Oracle's periodic feature-usage sampling has run.
SELECT name, detected_usages, currently_used
FROM   dba_feature_usage_statistics
WHERE  UPPER(name) LIKE '%VECTOR%';

-- OS-level cross-check (run in a shell, not in SQL*Plus):
--   $ORACLE_HOME/OPatch/opatch lspatches
