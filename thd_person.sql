REM THD_PERSON_DIM is the main view for The Housing Director to copy from Banner
REM  into THD when using the import functionality in the DIM
REM (it should have the same columns as THD_PERSON but differ in the WHERE clause)
-- #############################################################################
-- this view should be created under user BANINST1 (because of privs to underlying tables)
--   ZXD 2013-9   added EFC, BUSINESS_HOLD , 
--   ZXD 2013-8	added PHOTOPATH
-- \	  
-- #############################################################################
SET SCAN OFF
WHENEVER SQLERROR CONTINUE;
DROP PUBLIC SYNONYM THD_PERSON_DIM;
-- WHENEVER SQLERROR EXIT ROLLBACK;

CREATE OR REPLACE FORCE VIEW THD_PERSON_DIM
AS 
SELECT
    -- RPAAWRD - EFC Effective family contribution    
    (SELECT rorstat_pri_sar_pgi from rorstat
      WHERE rorstat_aidY_code = 
            (select a.stvterm_FA_proc_yr from stvterm a
              where a.stvterm_end_date =( select min(b.stvterm_end_date) from stvterm b
                                  where b.stvterm_end_date > sysdate 
                                  and substr(b.stvterm_code,5,1) = '0')
              and substr(a.stvterm_code,5,1) = '0')
      AND rorstat_pidm =SPRIDEN_PIDM)           EFC,
    (select sum(tbraccd_balance) from tbraccd where tbraccd_pidm = SPRIDEN_PIDM )       BUSINESS_HOLD, -- SOAHOLD - Business Office Hold
  
    'o:\'|| substr(onecardx_iso,7,9)||'-A.jpg'  PHOTOPATH, -- for display student photo in O:\
		    STVTERM_CODE                TERM_CODE,
		    SPRIDEN_PIDM                PERSON_UID,
		    SPRIDEN_ID                  ID_NUMBER,
		    SPRIDEN_LAST_NAME             LAST_NAME,
		    SPRIDEN_FIRST_NAME            FIRST_NAME,
    SPRIDEN_MI                    MIDDLE_NAME,
    SUBSTR(SPRIDEN_MI,1,1)        MIDDLE_INITIAL,
    SPBPERS_PREF_FIRST_NAME       PREFERRED_FIRST_NAME,
    SPBPERS_BIRTH_DATE            BIRTH_DATE,
    to_char(trunc((sysdate-spbpers_birth_date)/365),'99') AGE,
    decode(SPBPERS_CONFID_IND,'Y',-1,null)    CONFIDENTIALITY_IND,
    decode(SPBPERS_SEX,'M','M','F','F',null)  GENDER,
    STVRELG_DESC                              RELIGION,
    GOREMAL_EMAIL_ADDRESS                     EMAIL_PREFERRED_ADDRESS,
    decode(l.spraddr_atyp_code,null,
     decode(p.spraddr_atyp_code,null,
      decode(b.spraddr_atyp_code,null,null,
        cnty3.stvcnty_desc),
        cnty2.stvcnty_desc),
        cnty1.stvcnty_desc)                   COUNTY,

    (select distinct decode(sgbstdn_styp_code,'1','New','2','New','3','Transfer',    -- add distinct to make it only one entry
            '5','Continuing','8','Continuing',null)
       from  sgbstdn
      where sgbstdn_pidm = spriden_pidm            
        and sgbstdn_term_code_eff = (select max(sgbstdn_term_code_eff) from sgbstdn
                                  where sgbstdn_term_code_eff <= stvterm_code
                                    and sgbstdn_pidm = spriden_pidm))     STATUS,

    (select max(nvl(stvapdc_desc,'Pending')||' ('||saradap_term_code_entry||')')       
       from stvapdc, sarappd, saradap
      where sarappd_apdc_code          = stvapdc_code(+)
        and sarappd_term_code_entry(+) = saradap_term_code_entry
        and sarappd_pidm(+)            = saradap_pidm             
        and sarappd_appl_no(+)         = saradap_appl_no
        and saradap_term_code_entry||to_char(saradap_appl_no,99) =
                (select max(saradap_term_code_entry||to_char(saradap_appl_no,99))
                from saradap
                where spriden_pidm      = saradap_pidm
                  and saradap_term_code_entry <= stvterm_code)
        and spriden_pidm = saradap_pidm)                    APPLICATIONDECISION,

    (select to_char(nvl(sum(tbrdepo_amount),0) -
             nvl(sum(tbvdepo_m_sum_amount),0),'9999.99')
        from mesa.tbvdepo_m, tbrdepo
      where tbvdepo_m_tran_number (+) = tbrdepo_tran_number
        and tbvdepo_m_pidm (+)        = tbrdepo_pidm
        and tbrdepo_detail_code_deposit = 'DEP4'
        and tbrdepo_pidm      = spriden_pidm)                  DEPOSITBALANCE,

    (select to_char(trunc(shrlgpa_gpa,2),'999.99') from shrlgpa, sgbstdn
      where sgbstdn_pidm = spriden_pidm
        and sgbstdn_term_code_eff = (select max(sgbstdn_term_code_eff) from sgbstdn
                                  where sgbstdn_term_code_eff <= stvterm_code
                                    and sgbstdn_pidm = spriden_pidm)
        and shrlgpa_gpa_type_ind = 'O'
        and shrlgpa_levl_code = sgbstdn_levl_code
        and shrlgpa_pidm = sgbstdn_pidm)                          GPA,

    (select to_char(shrlgpa_gpa_hours,'999') from shrlgpa, sgbstdn
      where sgbstdn_pidm = spriden_pidm
        and sgbstdn_term_code_eff = (select max(sgbstdn_term_code_eff) from sgbstdn
                                  where sgbstdn_term_code_eff <= stvterm_code
                                    and sgbstdn_pidm = spriden_pidm)
    and shrlgpa_gpa_type_ind = 'O'
    and shrlgpa_levl_code = sgbstdn_levl_code
    and shrlgpa_pidm = sgbstdn_pidm)                    CREDITHOURS,

    (select sgbstdn_majr_code_1||' - '||stvmajr_desc from stvmajr, sgbstdn
      where sgbstdn_pidm = spriden_pidm
        and sgbstdn_term_code_eff = (select max(sgbstdn_term_code_eff) from sgbstdn
                                  where sgbstdn_term_code_eff <= stvterm_code
                                    and sgbstdn_pidm = spriden_pidm)
        and stvmajr_code = sgbstdn_majr_code_1)                 MAJOR,

    decode(f_class_calc_fnc(spriden_pidm, '01', stvterm_code),
           '11','Freshman',
           '12','Sophomore',
           '13','Junior',
           '14','Senior',
                 null)                                            CLASSSTATUS,

    rokmisc.f_calc_stud_credit_hrs(stvterm_code, spriden_pidm) CREDITHOURSSEMESTER,
-- need this one twice, once for general tab and once for attribute tab
    rokmisc.f_calc_stud_credit_hrs(stvterm_code, spriden_pidm) SEMESTERCREDITS,
    nvl(l.spraddr_street_line1,nvl(p.spraddr_street_line1,b.spraddr_street_line1)) ADDRESS,

    decode(l.spraddr_atyp_code,null,
     decode(p.spraddr_atyp_code,null,
      decode(b.spraddr_atyp_code,null,null,
        b.spraddr_street_line2),
        p.spraddr_street_line2),
        l.spraddr_street_line2)                             ADDRESSSECOND,

    nvl(l.spraddr_city,nvl(p.spraddr_city,b.spraddr_city))    CITY,
    nvl(l.spraddr_stat_code,nvl(p.spraddr_stat_code,b.spraddr_stat_code)) STATEORPROVINCE,
    nvl(l.spraddr_zip,nvl(p.spraddr_zip,b.spraddr_zip))                   POSTALCODE,
    decode(l.spraddr_atyp_code,null,
     decode(p.spraddr_atyp_code,null,
      decode(b.spraddr_atyp_code,null,null,
        z.stvnatn_nation),
        y.stvnatn_nation),
        x.stvnatn_nation)                                             COUNTRY,
    nvl(p.spraddr_street_line1,b.spraddr_street_line1)          ADDRESS2,
    
    decode(p.spraddr_atyp_code,null,
      decode(b.spraddr_atyp_code,null,null,
        b.spraddr_street_line2),
        p.spraddr_street_line2)                                   ADDRESSSECOND2,
    nvl(p.spraddr_city,b.spraddr_city)                          CITY2,
    nvl(p.spraddr_stat_code,b.spraddr_stat_code)                STATEORPROVINCE2,
    nvl(p.spraddr_zip,b.spraddr_zip)                    POSTALCODE2,
    
    decode(p.spraddr_atyp_code,null,
      decode(b.spraddr_atyp_code,null,null,
        z.stvnatn_nation),
        y.stvnatn_nation)                               COUNTRY2,
    b.spraddr_street_line1                        OFFCAMPUSADDRESS,
    decode(b.spraddr_atyp_code,null,null,
        b.spraddr_street_line2)                   OFFCAMPUSADDRESSSECOND,
    b.spraddr_city                            OFFCAMPUSCITY,
    b.spraddr_stat_code                           OFFCAMPUSSTATE,
    b.spraddr_zip                               OFFCAMPUSZIPCODE,
    
    decode(o.sprtele_atyp_code,null,
     decode(r.sprtele_atyp_code,null,
      decode(i.sprtele_atyp_code,null,null,
        '('||i.sprtele_phone_area||')'||
              substr(i.sprtele_phone_number,1,3)||'-'||
              substr(i.sprtele_phone_number,4,4)),
        '('||r.sprtele_phone_area||')'||
              substr(r.sprtele_phone_number,1,3)||'-'||
              substr(r.sprtele_phone_number,4,4)),
        '('||o.sprtele_phone_area||')'||
              substr(o.sprtele_phone_number,1,3)||'-'||
              substr(o.sprtele_phone_number,4,4))       PHONENUMBER,
    decode(lo.sprtele_atyp_code,null,null,
        '('||lo.sprtele_phone_area||')'||
              substr(lo.sprtele_phone_number,1,3)||'-'||
              substr(lo.sprtele_phone_number,4,4)) LOCALPHONE,
    SYSDATE                                       CURRENT_DATE

FROM 
       spraddr p, spraddr b, sprtele r, sprtele i, spraddr l, sprtele o,
       sprtele lo, stvrelg,mesa.onecardx,
       mesa.county_m mcnty1, mesa.county_m mcnty2, mesa.county_m mcnty3,
       stvcnty cnty1, stvcnty cnty2, stvcnty cnty3,
       stvnatn x, stvnatn y, stvnatn z,
       GOREMAL, SPBPERS, SPRIDEN, stvterm, 
-- add this section to thd_person
       housinguser.tblTimeFrame TF,
       housinguser.tblStudents  Stu,
       housinguser.tblStudentTimeFrames  TSFR

WHERE 
       SPRIDEN_CHANGE_IND IS NULL
   AND SPRIDEN_ENTITY_IND = 'P'
-- add this section to thd_person
   AND TF.TIMEFRAMEID         = TSFR.TIMEFRAMEID
   AND TF.TIMEFRAMENUMERICCODE = stvterm_code
   AND TSFR.STUDENTID         = Stu.STUDENTID
   AND spriden_id             = Stu.STUDENTNUMBER
   AND SPRIDEN_PIDM           = SPBPERS_PIDM (+)
   AND onecardx_ssn(+)        = spriden_id
   AND STVRELG_CODE(+)        = SPBPERS_RELG_CODE
   AND GOREMAL.ROWID (+)      = F_GET_EMAIL_ROWID (SPRIDEN_PIDM, NULL, 'A', 1)
-- remove this section (for the DIM the specific term is tacked on by the software)
-- AND stvterm_code = (select min(stvterm_code)
--	from saturn.stvterm 
--     where stvterm_end_date > sysdate
--       and stvterm_code not like '%3')
    AND upper (l.spraddr_city)       = upper(mcnty1.county_city(+))
    AND substr(l.spraddr_zip,1,5)    = mcnty1.county_zip(+)
    AND nvl(mcnty1.county_code,'00') = cnty1.stvcnty_code(+)
    AND upper (p.spraddr_city)       = upper(mcnty2.county_city(+))
    AND substr(p.spraddr_zip,1,5)    = mcnty2.county_zip(+)
    AND nvl(mcnty2.county_code,'00') = cnty2.stvcnty_code(+)
    AND upper (b.spraddr_city)       = upper(mcnty3.county_city(+))
    AND substr(b.spraddr_zip,1,5)    = mcnty3.county_zip(+)
    AND nvl(mcnty3.county_code,'00') = cnty3.stvcnty_code(+)
    AND l.spraddr_atyp_code(+) = 'PR'
    AND l.spraddr_pidm(+) = spriden_pidm
    AND (l.spraddr_seqno = (select max(spraddr_seqno) from spraddr
                               where spraddr_pidm = spriden_pidm
                                 and spraddr_atyp_code = 'PR')
      or l.spraddr_seqno is null)
    AND p.spraddr_atyp_code(+) = 'MA'
    AND p.spraddr_pidm(+) = spriden_pidm
    AND (p.spraddr_seqno = (select max(spraddr_seqno) from spraddr
                               where spraddr_pidm = spriden_pidm
                                 and spraddr_atyp_code = 'MA')
      or p.spraddr_seqno is null)
    AND b.spraddr_atyp_code(+) = 'BI'
    AND b.spraddr_pidm(+) = spriden_pidm
    AND (b.spraddr_seqno = (select max(spraddr_seqno) from spraddr
                               where spraddr_pidm = spriden_pidm
                                 and spraddr_atyp_code = 'BI')
      or b.spraddr_seqno is null)
    AND lo.sprtele_tele_code(+) = 'LO'
    AND lo.sprtele_pidm(+) = spriden_pidm
    AND (lo.sprtele_seqno = (select max(sprtele_seqno) from sprtele
                               where sprtele_pidm = spriden_pidm
                                 and sprtele_tele_code = 'LO')
      or lo.sprtele_seqno is null)
    AND o.sprtele_tele_code(+) = 'PR'
    AND o.sprtele_pidm(+) = spriden_pidm
    AND (o.sprtele_seqno = (select max(sprtele_seqno) from sprtele
                               where sprtele_pidm = spriden_pidm
                                 and sprtele_tele_code = 'PR')
      or o.sprtele_seqno is null)
    AND r.sprtele_tele_code(+) = 'MA'
    AND r.sprtele_pidm(+) = spriden_pidm
    AND (r.sprtele_seqno = (select max(sprtele_seqno) from sprtele
                               where sprtele_pidm = spriden_pidm
                                 and sprtele_tele_code = 'MA')
      or r.sprtele_seqno is null)
    AND i.sprtele_tele_code(+) = 'BI'
    AND i.sprtele_pidm(+) = spriden_pidm
    AND (i.sprtele_seqno = (select max(sprtele_seqno) from sprtele
                               where sprtele_pidm = spriden_pidm
                                 and sprtele_tele_code = 'BI')
      or i.sprtele_seqno is null)
    AND x.stvnatn_code(+) = l.spraddr_natn_code
    AND y.stvnatn_code(+) = p.spraddr_natn_code
    AND z.stvnatn_code(+) = b.spraddr_natn_code;

SHOW ERRORS VIEW THD_PERSON_DIM;
--
CREATE PUBLIC SYNONYM THD_PERSON_DIM FOR THD_PERSON_DIM;

grant select on thd_person_dim to housinguser;
grant select on thd_person_dim to dim_admin;
