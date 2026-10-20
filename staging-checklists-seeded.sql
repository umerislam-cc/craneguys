-- ─── RUN THIS FIRST *ONLY* IF YOU ALREADY RAN staging-checklists.sql ─────────
-- That earlier file created a near-identical set under different ids. Leaving both
-- in place would show every Pre/Post-Trip checklist TWICE in the app, because both
-- copies match the same assets. This removes only that earlier set, and only while
-- nothing has been answered against it.
--
-- DELETE FROM checklist_items  WHERE group_id IN (
--   SELECT id FROM checklist_groups WHERE checklist_id IN (
--     SELECT id FROM checklists WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8'
--       AND checklist_code IN ('CHKL-00001','CHKL-00002','CHKL-00003','CHKL-00004',
--                              'CHKL-00005','CHKL-00006','CHKL-00007')
--       AND id NOT IN (SELECT checklist_id FROM checklist_assignments)));
-- DELETE FROM checklist_groups WHERE checklist_id IN (
--   SELECT id FROM checklists WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8'
--     AND id NOT IN (SELECT checklist_id FROM checklist_assignments));
-- DELETE FROM checklists WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8'
--   AND id NOT IN (SELECT checklist_id FROM checklist_assignments);

-- Checklist definitions for tenant ec5404f8-1679-4d8d-bee9-ae3470f2cba8
--
-- Reproduces exactly what `seedChecklists()` (apps/api/src/utility/seed-data.ts)
-- would create: same 7 checklists, same CHKL codes, same item text and ordering,
-- and the same category / sub-category links resolved by NAME.
--
-- Idempotent: every insert is guarded on (tenant, name), so re-running is a no-op.

BEGIN;

-- 1. Crane Pre-Trip Inspection  [PRE_TRIP]  CHKL-00001
INSERT INTO checklists (id, tenant_company_id, checklist_code, type, name, description,
                        category_id, sub_category_id, version, is_active, created_at, updated_at)
SELECT '9d8e49b0-1874-52a0-b9ed-362aab87baa6', 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8', 'CHKL-00001', 'PRE_TRIP', 'Crane Pre-Trip Inspection', 'Crane inspection completed before leaving the yard.',
       (SELECT id FROM categories WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8' AND name = 'Cranes'),
       NULL,
       1, true, now(), now()
WHERE NOT EXISTS (SELECT 1 FROM checklists
                  WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8' AND name = 'Crane Pre-Trip Inspection');

INSERT INTO checklist_groups (id, checklist_id, name, position, created_at, updated_at)
SELECT '5a949dfa-86dd-5f93-a7a6-72493e51fc5e', '9d8e49b0-1874-52a0-b9ed-362aab87baa6', 'Inspection', 0, now(), now()
WHERE EXISTS (SELECT 1 FROM checklists WHERE id = '9d8e49b0-1874-52a0-b9ed-362aab87baa6')
  AND NOT EXISTS (SELECT 1 FROM checklist_groups WHERE checklist_id = '9d8e49b0-1874-52a0-b9ed-362aab87baa6');

INSERT INTO checklist_items (id, group_id, kind, title, description, title_es,
                             is_required, position, created_at, updated_at)
SELECT v.id, v.group_id, v.kind::"ChecklistItemKind", v.title, NULL, NULL,
       v.is_required, v.position, now(), now()
FROM (VALUES
  ('9d5e8907-854e-5150-b24b-301749e27871'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Load Line / Hook / Sheaves', true::boolean, 0),
  ('9de9a3c5-4644-58e1-a718-7e28653d9150'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Straps / Shackles / Tag Line / Air Port Flag / Safety Chains / Rope', true::boolean, 1),
  ('30fd03b6-8bdb-5db4-bd7a-c06d3d44a1f3'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Spill and Clean Kits / Cones / Wheel Chalks / Fire Extinguisher', true::boolean, 2),
  ('fc8536b5-0bfb-55e0-8669-4b00b9a7329d'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Crane Annual and Quad Certification Stickers', true::boolean, 3),
  ('eb5049e1-f9d8-586d-a851-3e04a2abfa59'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Head Lights / Running Lights / Auxiliary Lights', true::boolean, 4),
  ('4385c457-ee8c-5e41-9ee5-af4dc38a3972'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Warning Labels', true::boolean, 5),
  ('6de2de8e-778b-54ee-bf94-aed2c56dd8d2'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Coolant Level', true::boolean, 6),
  ('3474121d-052e-5ec6-9fc4-24ea7011723f'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Engine Oil', true::boolean, 7),
  ('d37087ea-393a-54e2-bc48-84241d994d1a'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Belts and Pulleys', true::boolean, 8),
  ('f9467446-4269-58a9-ac28-ffa2776a4aeb'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Seat Belts', true::boolean, 9),
  ('8c6038c7-a463-5358-858f-68df9261407c'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Tire and Lugnuts', true::boolean, 10),
  ('046b89a9-ee4d-5a05-951b-89408d57ce41'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Mud Flats', true::boolean, 11),
  ('18f6ecb4-b0f6-5a81-bfd5-fa484fa1b6f7'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Windows and Mirrors', true::boolean, 12),
  ('aa23df97-8c77-5b54-9bcf-4047bd6e4499'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Brake Operation', true::boolean, 13),
  ('7026d119-393c-59bb-be52-5232c413bbc6'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Compliance: Registration / Tags / Annual Permits / Operating Manual / Load Chart', true::boolean, 14),
  ('c6d8e783-ec0d-5ae4-82c3-9c56b39b15ad'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Annual Permits', true::boolean, 15),
  ('97cd6664-6863-5fd8-ac26-b3a4c98363a5'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'INSPECTION', 'Additional Comments', true::boolean, 16),
  ('4e8864d1-1ed7-58fb-9ff5-525b552a09ee'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'PHOTO_SLOT', 'Front', false::boolean, 17),
  ('f63c2f51-52f9-53a5-bd8b-483229ee5f2e'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'PHOTO_SLOT', 'Rear', false::boolean, 18),
  ('cf80cd29-cc4b-5f0d-84e3-b12f76885150'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'PHOTO_SLOT', 'Left side', false::boolean, 19),
  ('1c134654-f788-5f2b-9edd-3cce9999b474'::uuid, '5a949dfa-86dd-5f93-a7a6-72493e51fc5e'::uuid, 'PHOTO_SLOT', 'Right side', false::boolean, 20)
) AS v(id, group_id, kind, title, is_required, position)
WHERE EXISTS (SELECT 1 FROM checklist_groups WHERE id = '5a949dfa-86dd-5f93-a7a6-72493e51fc5e')
  AND NOT EXISTS (SELECT 1 FROM checklist_items ci WHERE ci.id = v.id);

-- 2. Tractor Pre-Trip Inspection  [PRE_TRIP]  CHKL-00002
INSERT INTO checklists (id, tenant_company_id, checklist_code, type, name, description,
                        category_id, sub_category_id, version, is_active, created_at, updated_at)
SELECT '432fe644-8265-5c06-8782-4adf38930e1f', 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8', 'CHKL-00002', 'PRE_TRIP', 'Tractor Pre-Trip Inspection', 'Tractor inspection completed before leaving the yard.',
       NULL,
       (SELECT id FROM sub_categories WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8' AND name = 'Tractor'),
       1, true, now(), now()
WHERE NOT EXISTS (SELECT 1 FROM checklists
                  WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8' AND name = 'Tractor Pre-Trip Inspection');

INSERT INTO checklist_groups (id, checklist_id, name, position, created_at, updated_at)
SELECT '3d9c883a-2122-5706-85d3-c95c192915ec', '432fe644-8265-5c06-8782-4adf38930e1f', 'Inspection', 0, now(), now()
WHERE EXISTS (SELECT 1 FROM checklists WHERE id = '432fe644-8265-5c06-8782-4adf38930e1f')
  AND NOT EXISTS (SELECT 1 FROM checklist_groups WHERE checklist_id = '432fe644-8265-5c06-8782-4adf38930e1f');

INSERT INTO checklist_items (id, group_id, kind, title, description, title_es,
                             is_required, position, created_at, updated_at)
SELECT v.id, v.group_id, v.kind::"ChecklistItemKind", v.title, NULL, NULL,
       v.is_required, v.position, now(), now()
FROM (VALUES
  ('499f6a7e-0f00-5842-b7f1-ed59ec3ef76e'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Chains / Binders', true::boolean, 0),
  ('62efcc58-cfb8-5c7b-a41b-6e2bbb09e7de'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Straps / Shackles', true::boolean, 1),
  ('fee2998e-c9fb-5e93-b13a-bf39e804cfc5'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Spill and Clean Kits', true::boolean, 2),
  ('e12e465b-eb4e-59d7-910e-978d24728167'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Air Hoses', true::boolean, 3),
  ('ab2624c4-2946-56c6-9c13-e9f4085d210c'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Inspection Stickers', true::boolean, 4),
  ('80aecddd-ffd4-5eb0-b859-e859d8dcbfc1'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'PPE', true::boolean, 5),
  ('85f43f0e-43ce-57cc-be15-16388e9a007a'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Auxiliary Lights', true::boolean, 6),
  ('d78fedbc-8adf-5dad-8b72-416b545004a8'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Safety Chains and Tape', true::boolean, 7),
  ('97b06729-58cc-5a3a-8d61-9fd4496279e0'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Warning Labels', true::boolean, 8),
  ('0b326269-1885-58d6-bab9-7464ef07a748'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Coolant Level', true::boolean, 9),
  ('937ed0f8-1068-5516-8fad-9ac0c42d7e2c'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Engine Oil', true::boolean, 10),
  ('cb731339-a88a-5a91-a2a1-9ceebe34e72f'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Belts and Pulleys', true::boolean, 11),
  ('631800af-d1fc-509f-a8f9-5340e6d97d19'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Seat Belts', true::boolean, 12),
  ('73eae192-f43e-544f-8758-5df85e96a7b1'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Hydraulic Oil Level', true::boolean, 13),
  ('41fb45ef-fe40-5d1d-8717-0e1c27ca5be2'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Power Steering Fluid', true::boolean, 14),
  ('603c2232-b136-50e2-9c1f-a3e54548ec1c'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Tires and Lugnuts', true::boolean, 15),
  ('487abaf5-143a-5418-9c20-00c20fbbf76b'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Mud Flaps and Rims', true::boolean, 16),
  ('2bc9d317-8ca3-5ee4-a2b8-5ab5aa6d8ae2'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Windows and Mirrors', true::boolean, 17),
  ('bb1238df-9333-55a3-b814-83283316f684'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Lights and Signals', true::boolean, 18),
  ('ad7d9455-af7b-5c76-9460-72ae415c236e'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Brake Operation', true::boolean, 19),
  ('43e74b6a-c511-5b0a-be60-0cf8c7d5ce46'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Registration and Tags', true::boolean, 20),
  ('fab986d5-72f4-5d75-92f7-be2099f714bd'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Insurance Cards', true::boolean, 21),
  ('1d4719a9-f154-57fe-885f-11afbce8860b'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Travel Permits', true::boolean, 22),
  ('2063d3ff-baba-5be0-aec9-bd422eaa7506'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Trailer Connections', true::boolean, 23),
  ('501d1c1c-0dba-5636-9737-6fc8b7c1e8eb'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Load Strapped Down', true::boolean, 24),
  ('8049ae85-c7ad-568f-91d2-0c39a8b606fb'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'INSPECTION', 'Additional Comments', true::boolean, 25),
  ('a66d0631-d5b7-5b9f-aa3f-5710979bd381'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'PHOTO_SLOT', 'Front corner', false::boolean, 26),
  ('c944f044-1a33-5d1b-a4b4-8bc8cded8ad0'::uuid, '3d9c883a-2122-5706-85d3-c95c192915ec'::uuid, 'PHOTO_SLOT', 'Rear', false::boolean, 27)
) AS v(id, group_id, kind, title, is_required, position)
WHERE EXISTS (SELECT 1 FROM checklist_groups WHERE id = '3d9c883a-2122-5706-85d3-c95c192915ec')
  AND NOT EXISTS (SELECT 1 FROM checklist_items ci WHERE ci.id = v.id);

-- 3. Trailer Pre-Trip Inspection  [PRE_TRIP]  CHKL-00003
INSERT INTO checklists (id, tenant_company_id, checklist_code, type, name, description,
                        category_id, sub_category_id, version, is_active, created_at, updated_at)
SELECT 'bb4cd187-335e-5ff1-822e-a195bcebef37', 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8', 'CHKL-00003', 'PRE_TRIP', 'Trailer Pre-Trip Inspection', 'Trailer inspection completed before leaving the yard.',
       (SELECT id FROM categories WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8' AND name = 'Trailers'),
       NULL,
       1, true, now(), now()
WHERE NOT EXISTS (SELECT 1 FROM checklists
                  WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8' AND name = 'Trailer Pre-Trip Inspection');

INSERT INTO checklist_groups (id, checklist_id, name, position, created_at, updated_at)
SELECT '0bc6cb70-afa0-5f05-93f3-38b7480164af', 'bb4cd187-335e-5ff1-822e-a195bcebef37', 'Inspection', 0, now(), now()
WHERE EXISTS (SELECT 1 FROM checklists WHERE id = 'bb4cd187-335e-5ff1-822e-a195bcebef37')
  AND NOT EXISTS (SELECT 1 FROM checklist_groups WHERE checklist_id = 'bb4cd187-335e-5ff1-822e-a195bcebef37');

INSERT INTO checklist_items (id, group_id, kind, title, description, title_es,
                             is_required, position, created_at, updated_at)
SELECT v.id, v.group_id, v.kind::"ChecklistItemKind", v.title, NULL, NULL,
       v.is_required, v.position, now(), now()
FROM (VALUES
  ('648be5e1-c200-5019-a25e-63c0e35276fe'::uuid, '0bc6cb70-afa0-5f05-93f3-38b7480164af'::uuid, 'INSPECTION', 'Insurance and Registration', true::boolean, 0),
  ('530d5639-f156-5fb2-b1dc-faa4d87dbfc4'::uuid, '0bc6cb70-afa0-5f05-93f3-38b7480164af'::uuid, 'INSPECTION', 'Wheel Chalks', true::boolean, 1),
  ('920886bc-6820-594f-9592-c4d201c5e1e1'::uuid, '0bc6cb70-afa0-5f05-93f3-38b7480164af'::uuid, 'INSPECTION', 'DOT Tape', true::boolean, 2),
  ('9570b404-e09c-530a-81ce-5b083495e7fc'::uuid, '0bc6cb70-afa0-5f05-93f3-38b7480164af'::uuid, 'INSPECTION', 'Deck Condition', true::boolean, 3),
  ('d95f2706-491d-55fe-a4d9-58f6d40fd1ad'::uuid, '0bc6cb70-afa0-5f05-93f3-38b7480164af'::uuid, 'PHOTO_SLOT', 'Deck & gooseneck', false::boolean, 4),
  ('62e3c5b5-5e4e-5e6c-a4b1-1be6c19f047a'::uuid, '0bc6cb70-afa0-5f05-93f3-38b7480164af'::uuid, 'PHOTO_SLOT', 'Tires & axles', false::boolean, 5)
) AS v(id, group_id, kind, title, is_required, position)
WHERE EXISTS (SELECT 1 FROM checklist_groups WHERE id = '0bc6cb70-afa0-5f05-93f3-38b7480164af')
  AND NOT EXISTS (SELECT 1 FROM checklist_items ci WHERE ci.id = v.id);

-- 4. Crane Post-Trip Inspection  [POST_TRIP]  CHKL-00004
INSERT INTO checklists (id, tenant_company_id, checklist_code, type, name, description,
                        category_id, sub_category_id, version, is_active, created_at, updated_at)
SELECT 'd6a6476e-851b-50f6-b808-60037f8adaf6', 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8', 'CHKL-00004', 'POST_TRIP', 'Crane Post-Trip Inspection', 'Crane inspection completed after returning to the yard.',
       (SELECT id FROM categories WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8' AND name = 'Cranes'),
       NULL,
       1, true, now(), now()
WHERE NOT EXISTS (SELECT 1 FROM checklists
                  WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8' AND name = 'Crane Post-Trip Inspection');

INSERT INTO checklist_groups (id, checklist_id, name, position, created_at, updated_at)
SELECT '73593227-1385-5bb0-8990-b6d499aaedad', 'd6a6476e-851b-50f6-b808-60037f8adaf6', 'Inspection', 0, now(), now()
WHERE EXISTS (SELECT 1 FROM checklists WHERE id = 'd6a6476e-851b-50f6-b808-60037f8adaf6')
  AND NOT EXISTS (SELECT 1 FROM checklist_groups WHERE checklist_id = 'd6a6476e-851b-50f6-b808-60037f8adaf6');

INSERT INTO checklist_items (id, group_id, kind, title, description, title_es,
                             is_required, position, created_at, updated_at)
SELECT v.id, v.group_id, v.kind::"ChecklistItemKind", v.title, NULL, NULL,
       v.is_required, v.position, now(), now()
FROM (VALUES
  ('a8df823b-4fc4-5b9f-9004-82729ac8ea89'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Load Line / Hook / Sheaves', true::boolean, 0),
  ('6320665c-5ade-5658-b11b-724ece6e397b'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Straps / Shackles / Tag Line / Air Port Flag / Safety Chains / Rope', true::boolean, 1),
  ('db699e61-aaba-5a01-9dbb-3e4bb1cf1e5b'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Spill and Clean Kits / Cones / Wheel Chalks / Fire Extinguisher', true::boolean, 2),
  ('6d65bd51-74c7-520f-939b-312874122077'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Crane Annual and Quad Certification Stickers', true::boolean, 3),
  ('f820d11e-faeb-5447-9c30-8fd3912d07a5'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Head Lights / Running Lights / Auxiliary Lights', true::boolean, 4),
  ('dd63a32f-3266-53ad-9369-f96ac868170b'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Warning Labels', true::boolean, 5),
  ('aa22c9df-2595-5c60-adc7-e3d7c60790cd'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Coolant Level', true::boolean, 6),
  ('55612d7a-fb62-5f4e-8795-c60e46e66010'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Engine Oil', true::boolean, 7),
  ('6d6f15e7-cde7-5068-8e08-5817576a5980'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Belts and Pulleys', true::boolean, 8),
  ('83d0f6d6-3a05-5ebf-9db4-e2288ea5e8da'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Seat Belts', true::boolean, 9),
  ('654b5595-0dcf-5d76-84d6-570667e0c107'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Tire and Lugnuts', true::boolean, 10),
  ('d85e93e3-54cb-5f5a-8a08-0e402856773d'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Mud Flats', true::boolean, 11),
  ('167e8340-bb75-554b-8f2e-1ceee7600b91'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Windows and Mirrors', true::boolean, 12),
  ('e40bd994-a616-567c-8d9e-1261ebcc3932'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Brake Operation', true::boolean, 13),
  ('35f3fdeb-5685-59aa-8d7b-09a7a620e762'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Compliance: Registration / Tags / Annual Permits / Operating Manual / Load Chart', true::boolean, 14),
  ('e4338a2f-bff9-564b-9aab-28968a7e2357'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Annual Permits', true::boolean, 15),
  ('e22022a5-e527-5322-a6ab-9975eeb16c2a'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'INSPECTION', 'Additional Comments', true::boolean, 16),
  ('0b1c80f9-a9f5-5e12-b4a7-6000f6e00151'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'PHOTO_SLOT', 'Front', false::boolean, 17),
  ('d411ab99-a242-5442-99ba-0a05644b269f'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'PHOTO_SLOT', 'Rear', false::boolean, 18),
  ('b349c329-bb73-5649-84f6-f69cd544c296'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'PHOTO_SLOT', 'Left side', false::boolean, 19),
  ('a3de7abe-36ca-5257-b2ca-5417806bcbea'::uuid, '73593227-1385-5bb0-8990-b6d499aaedad'::uuid, 'PHOTO_SLOT', 'Right side', false::boolean, 20)
) AS v(id, group_id, kind, title, is_required, position)
WHERE EXISTS (SELECT 1 FROM checklist_groups WHERE id = '73593227-1385-5bb0-8990-b6d499aaedad')
  AND NOT EXISTS (SELECT 1 FROM checklist_items ci WHERE ci.id = v.id);

-- 5. Tractor Post-Trip Inspection  [POST_TRIP]  CHKL-00005
INSERT INTO checklists (id, tenant_company_id, checklist_code, type, name, description,
                        category_id, sub_category_id, version, is_active, created_at, updated_at)
SELECT 'db0f5c34-fd5b-52c9-8ba9-f0623c17bebc', 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8', 'CHKL-00005', 'POST_TRIP', 'Tractor Post-Trip Inspection', 'Tractor inspection completed after returning to the yard.',
       NULL,
       (SELECT id FROM sub_categories WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8' AND name = 'Tractor'),
       1, true, now(), now()
WHERE NOT EXISTS (SELECT 1 FROM checklists
                  WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8' AND name = 'Tractor Post-Trip Inspection');

INSERT INTO checklist_groups (id, checklist_id, name, position, created_at, updated_at)
SELECT '804bc8a6-a862-55e3-b8e3-f9b290495f42', 'db0f5c34-fd5b-52c9-8ba9-f0623c17bebc', 'Inspection', 0, now(), now()
WHERE EXISTS (SELECT 1 FROM checklists WHERE id = 'db0f5c34-fd5b-52c9-8ba9-f0623c17bebc')
  AND NOT EXISTS (SELECT 1 FROM checklist_groups WHERE checklist_id = 'db0f5c34-fd5b-52c9-8ba9-f0623c17bebc');

INSERT INTO checklist_items (id, group_id, kind, title, description, title_es,
                             is_required, position, created_at, updated_at)
SELECT v.id, v.group_id, v.kind::"ChecklistItemKind", v.title, NULL, NULL,
       v.is_required, v.position, now(), now()
FROM (VALUES
  ('1d0777f8-e8df-56c8-9d9b-29b5341b788c'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Chains / Binders', true::boolean, 0),
  ('085538fa-4821-5756-abe3-f9181aa44b55'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Straps / Shackles', true::boolean, 1),
  ('0f87a3a5-3097-5494-9929-776b51717b76'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Spill and Clean Kits', true::boolean, 2),
  ('9e2e50dd-22c6-5c4b-927e-0633029962f1'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Air Hoses', true::boolean, 3),
  ('e0aadfc2-83ba-597d-8338-760ac175c3ad'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Inspection Stickers', true::boolean, 4),
  ('4cbc36ff-194e-5d59-bf75-4db12f217c9e'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'PPE', true::boolean, 5),
  ('086dfa7f-5fe1-5e58-9cb2-23922f2c0704'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Auxiliary Lights', true::boolean, 6),
  ('ca74d122-8c8a-5ce4-9b8e-abd6bdff7400'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Safety Chains and Tape', true::boolean, 7),
  ('276eca24-a472-599f-8990-29258150ab32'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Warning Labels', true::boolean, 8),
  ('2157aa13-6ed7-5859-b06e-02fb283ff30d'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Coolant Level', true::boolean, 9),
  ('e624164d-36f4-5a52-b8bc-2387b7ca12e8'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Engine Oil', true::boolean, 10),
  ('5a5f5c53-2150-524a-bc40-22a0d244910a'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Belts and Pulleys', true::boolean, 11),
  ('5e069f01-4e39-57a6-8354-5b5d079452c6'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Seat Belts', true::boolean, 12),
  ('9e4a47a6-c2c7-52a4-8d95-17f2419a0175'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Hydraulic Oil Level', true::boolean, 13),
  ('940062d6-fd10-5b8e-a1e7-49d419501750'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Power Steering Fluid', true::boolean, 14),
  ('a49174f9-7189-5e6d-891d-3595dfd4f386'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Tires and Lugnuts', true::boolean, 15),
  ('f427c108-e6fc-5b55-8252-55135b0b1e21'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Mud Flaps and Rims', true::boolean, 16),
  ('7ac8ae1c-21c7-5309-ab80-fbe6b27ea997'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Windows and Mirrors', true::boolean, 17),
  ('bf3bdc5e-11dd-5a71-bc48-4e737c4a46f8'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Lights and Signals', true::boolean, 18),
  ('ceabd14d-fdf7-50be-a590-a005243d2618'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Brake Operation', true::boolean, 19),
  ('887a82cb-cd16-5185-8b49-0a9fce358500'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Registration and Tags', true::boolean, 20),
  ('b0ba5efe-1683-5f83-9de3-50cb30288214'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Insurance Cards', true::boolean, 21),
  ('6504071c-ff7e-5178-96ae-3f2ac12a827f'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Travel Permits', true::boolean, 22),
  ('ce9c66b9-899f-59c1-8bd2-23d9af36c303'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Trailer Connections', true::boolean, 23),
  ('c292ee43-1700-5fb0-a422-4e9858d00a6d'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Load Strapped Down', true::boolean, 24),
  ('1e24b647-0373-5654-a70a-c2bd44dba858'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'INSPECTION', 'Additional Comments', true::boolean, 25),
  ('3aabc165-e96d-5a53-a3fe-7fb2d42f6f90'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'PHOTO_SLOT', 'Front corner', false::boolean, 26),
  ('b6a3e6cc-b910-5c64-91ba-5be4ae1a42d8'::uuid, '804bc8a6-a862-55e3-b8e3-f9b290495f42'::uuid, 'PHOTO_SLOT', 'Rear', false::boolean, 27)
) AS v(id, group_id, kind, title, is_required, position)
WHERE EXISTS (SELECT 1 FROM checklist_groups WHERE id = '804bc8a6-a862-55e3-b8e3-f9b290495f42')
  AND NOT EXISTS (SELECT 1 FROM checklist_items ci WHERE ci.id = v.id);

-- 6. Trailer Post-Trip Inspection  [POST_TRIP]  CHKL-00006
INSERT INTO checklists (id, tenant_company_id, checklist_code, type, name, description,
                        category_id, sub_category_id, version, is_active, created_at, updated_at)
SELECT 'cf7a5e0e-5cf2-527f-a5ce-c359b0e0db97', 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8', 'CHKL-00006', 'POST_TRIP', 'Trailer Post-Trip Inspection', 'Trailer inspection completed after returning to the yard.',
       (SELECT id FROM categories WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8' AND name = 'Trailers'),
       NULL,
       1, true, now(), now()
WHERE NOT EXISTS (SELECT 1 FROM checklists
                  WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8' AND name = 'Trailer Post-Trip Inspection');

INSERT INTO checklist_groups (id, checklist_id, name, position, created_at, updated_at)
SELECT 'a0a4c99e-07cc-59bc-b1b8-b059dde40905', 'cf7a5e0e-5cf2-527f-a5ce-c359b0e0db97', 'Inspection', 0, now(), now()
WHERE EXISTS (SELECT 1 FROM checklists WHERE id = 'cf7a5e0e-5cf2-527f-a5ce-c359b0e0db97')
  AND NOT EXISTS (SELECT 1 FROM checklist_groups WHERE checklist_id = 'cf7a5e0e-5cf2-527f-a5ce-c359b0e0db97');

INSERT INTO checklist_items (id, group_id, kind, title, description, title_es,
                             is_required, position, created_at, updated_at)
SELECT v.id, v.group_id, v.kind::"ChecklistItemKind", v.title, NULL, NULL,
       v.is_required, v.position, now(), now()
FROM (VALUES
  ('6740a3e3-fb64-58af-b741-2c212602fc82'::uuid, 'a0a4c99e-07cc-59bc-b1b8-b059dde40905'::uuid, 'INSPECTION', 'Insurance and Registration', true::boolean, 0),
  ('ad7fac8b-dc03-5014-acf2-6ee398fc70ae'::uuid, 'a0a4c99e-07cc-59bc-b1b8-b059dde40905'::uuid, 'INSPECTION', 'Wheel Chalks', true::boolean, 1),
  ('a0473f05-eadb-5115-a98b-c511b0e03e46'::uuid, 'a0a4c99e-07cc-59bc-b1b8-b059dde40905'::uuid, 'INSPECTION', 'DOT Tape', true::boolean, 2),
  ('d20efc81-6bc6-5931-bddd-0147f515859b'::uuid, 'a0a4c99e-07cc-59bc-b1b8-b059dde40905'::uuid, 'INSPECTION', 'Deck Condition', true::boolean, 3),
  ('43bb1149-eb68-5b46-985a-8d6b0953b7a2'::uuid, 'a0a4c99e-07cc-59bc-b1b8-b059dde40905'::uuid, 'PHOTO_SLOT', 'Deck & gooseneck', false::boolean, 4),
  ('1a822f32-d09a-5405-9d14-b86a291f76cd'::uuid, 'a0a4c99e-07cc-59bc-b1b8-b059dde40905'::uuid, 'PHOTO_SLOT', 'Tires & axles', false::boolean, 5)
) AS v(id, group_id, kind, title, is_required, position)
WHERE EXISTS (SELECT 1 FROM checklist_groups WHERE id = 'a0a4c99e-07cc-59bc-b1b8-b059dde40905')
  AND NOT EXISTS (SELECT 1 FROM checklist_items ci WHERE ci.id = v.id);

-- 7. Job Safety Analysis — Tailboard  [JSA]  CHKL-00007
INSERT INTO checklists (id, tenant_company_id, checklist_code, type, name, description,
                        category_id, sub_category_id, version, is_active, created_at, updated_at)
SELECT 'f24f9432-5495-5909-9eba-32a76ecaf337', 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8', 'CHKL-00007', 'JSA', 'Job Safety Analysis — Tailboard', 'Job-level tailboard hazard assessment completed on arrival at the site.',
       NULL,
       NULL,
       1, true, now(), now()
WHERE NOT EXISTS (SELECT 1 FROM checklists
                  WHERE tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8' AND name = 'Job Safety Analysis — Tailboard');

INSERT INTO checklist_groups (id, checklist_id, name, position, created_at, updated_at)
SELECT '055402ca-e166-58d5-b2fd-5661a74ff6d0', 'f24f9432-5495-5909-9eba-32a76ecaf337', 'Identify hazards present', 0, now(), now()
WHERE EXISTS (SELECT 1 FROM checklists WHERE id = 'f24f9432-5495-5909-9eba-32a76ecaf337')
  AND NOT EXISTS (SELECT 1 FROM checklist_groups WHERE checklist_id = 'f24f9432-5495-5909-9eba-32a76ecaf337');

INSERT INTO checklist_items (id, group_id, kind, title, description, title_es,
                             is_required, position, created_at, updated_at)
SELECT v.id, v.group_id, v.kind::"ChecklistItemKind", v.title, NULL, NULL,
       v.is_required, v.position, now(), now()
FROM (VALUES
  ('ecc6518b-9d4f-5fff-b047-255eef7dbff7'::uuid, '055402ca-e166-58d5-b2fd-5661a74ff6d0'::uuid, 'INSPECTION', 'Working Near Cranes / Suspended Loads / Falling Objects / Moving Machinery / Tag Lines / Lift Barricades / Ladders Used / Tools and Equipment / Sharp Metals', true::boolean, 0),
  ('38d8412c-4682-59a4-9475-88eb1bcac8f7'::uuid, '055402ca-e166-58d5-b2fd-5661a74ff6d0'::uuid, 'INSPECTION', 'PPE: Gloves / High Visibility Vests / Safety Glasses / Fall Arrest Systems', true::boolean, 1),
  ('20b42cfd-373b-5030-9079-8a57ecfe942d'::uuid, '055402ca-e166-58d5-b2fd-5661a74ff6d0'::uuid, 'INSPECTION', 'Site Conditions: Poor Lighting / Poor Visibility / Slippery Surfaces / Trip Hazards / Working at Heights / Flammable and Pressurized Fluids and Materials in Area / Inhalable Dust or Fibers / High Noise Area / Communication Difficulties / Street Permits / Lane Closures / FAA Permit / Pedestrian Control', true::boolean, 2),
  ('81b33e43-5923-5f21-98e7-75111d3855f4'::uuid, '055402ca-e166-58d5-b2fd-5661a74ff6d0'::uuid, 'INSPECTION', 'Rigging: Shackles / Chains / Slings / Cables / Spreader Bar', true::boolean, 3),
  ('6d9e5bfb-0b93-50a7-89f4-4993f650e630'::uuid, '055402ca-e166-58d5-b2fd-5661a74ff6d0'::uuid, 'INSPECTION', 'Electrical > 4001 AMPS / Multiple Electrical Feeds / Equipment Grounded', true::boolean, 4),
  ('14126877-0b73-5c29-ada1-cedb9a148a60'::uuid, '055402ca-e166-58d5-b2fd-5661a74ff6d0'::uuid, 'INSPECTION', 'Safety Meeting Performed', true::boolean, 5)
) AS v(id, group_id, kind, title, is_required, position)
WHERE EXISTS (SELECT 1 FROM checklist_groups WHERE id = '055402ca-e166-58d5-b2fd-5661a74ff6d0')
  AND NOT EXISTS (SELECT 1 FROM checklist_items ci WHERE ci.id = v.id);

-- Keep the CHKL counter ahead of the seeded codes, exactly as the seeder does,
-- so a checklist created later through the API cannot collide with these.
INSERT INTO entity_sequences (tenant_company_id, prefix, next_value)
VALUES ('ec5404f8-1679-4d8d-bee9-ae3470f2cba8', 'CHKL', 8)
ON CONFLICT (tenant_company_id, prefix)
DO UPDATE SET next_value = GREATEST(entity_sequences.next_value, 8);

COMMIT;

-- ─── Verify (run after COMMIT) ───────────────────────────────────────────────
-- Expect 7 rows. category_id/sub_category_id must be non-null for the 6
-- Pre/Post-Trip rows — if any is NULL, the named Category/Sub-Category does not
-- exist for this tenant and that checklist will only match on its name.
--
-- SELECT c.checklist_code, c.type, c.name, c.category_id, c.sub_category_id,
--        count(i.id) FILTER (WHERE i.kind = 'INSPECTION') AS inspections,
--        count(i.id) FILTER (WHERE i.kind = 'PHOTO_SLOT') AS photos
-- FROM checklists c
-- JOIN checklist_groups g ON g.checklist_id = c.id
-- JOIN checklist_items  i ON i.group_id     = g.id
-- WHERE c.tenant_company_id = 'ec5404f8-1679-4d8d-bee9-ae3470f2cba8'
-- GROUP BY 1,2,3,4,5 ORDER BY c.checklist_code;
