/*
  Purpose:      Master script — runs every schema/programmability/seed script
                in dependency order. Requires SQLCMD mode (SSMS: Query menu
                > SQLCMD Mode) because it uses :r include directives.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: TransitCoreDb must already exist (see README.md) and this
                script must be run from the /database folder so the relative
                :r paths resolve.
*/

:setvar SQLCMDMAXVARTYPEWIDTH 0

PRINT '--- 01-schema ---';
:r .\01-schema\001_lookup_core.sql
:r .\01-schema\002_identity_schema.sql
:r .\01-schema\003_identity_tvp.sql
:r .\01-schema\004_ops_schema.sql
:r .\01-schema\005_lookup_extended.sql
:r .\01-schema\006_fleet_schema.sql
:r .\01-schema\007_billing_customers_schema.sql
:r .\01-schema\008_ops_routes_trips_shipments_schema.sql
:r .\01-schema\009_billing_invoicing_schema.sql
:r .\01-schema\010_billing_tvp.sql
:r .\01-schema\011_ops_shipment_tvp.sql
:r .\01-schema\012_ops_phase3_schema.sql
:r .\01-schema\013_billing_phase4_schema.sql
:r .\01-schema\014_freight_parties_consignment_notes_schema.sql
:r .\01-schema\015_route_stops_active_stop_order.sql
:r .\01-schema\016_capacity_volume_trip_stop_shipments_schema.sql
:r .\01-schema\017_freight_calculation_shipment_charges_schema.sql
:r .\01-schema\018_hired_trucks_vendors_schema.sql
:r .\01-schema\019_empty_km_claims_schema.sql
:r .\01-schema\020_compliance_documents_eway_bills_schema.sql

PRINT '--- 02-programmability ---';
:r .\02-programmability\001_identity_procs.sql
:r .\02-programmability\002_lookup_procs.sql
:r .\02-programmability\003_identity_user_management_procs.sql
:r .\02-programmability\004_ops_vehicleordermapping_procs.sql
:r .\02-programmability\005_fleet_procs.sql
:r .\02-programmability\006_ops_procs.sql
:r .\02-programmability\007_billing_procs.sql
:r .\02-programmability\008_lookup_statuscodes_proc.sql
:r .\02-programmability\009_ops_shipment_procs.sql
:r .\02-programmability\010_lookup_cities_proc.sql
:r .\02-programmability\011_lookup_unitsofmeasure_proc.sql
:r .\02-programmability\012_edit_endpoints_procs.sql
:r .\02-programmability\013_vehicle_documents_maintenance_fuel_procs.sql
:r .\02-programmability\014_driver_licenses_performance_procs.sql
:r .\02-programmability\015_trip_expenses_advances_procs.sql
:r .\02-programmability\016_proof_of_delivery_documents_incidents_procs.sql
:r .\02-programmability\017_route_stops_dispatch_tracking_procs.sql
:r .\02-programmability\018_shipment_tracking_no_insert_update.sql
:r .\02-programmability\019_shipment_get_procs_tracking_no.sql
:r .\02-programmability\020_billing_ratecards_customer_invoice_procs.sql
:r .\02-programmability\021_billing_payments_aging_settlement_procs.sql
:r .\02-programmability\022_identity_user_roles_procs.sql
:r .\02-programmability\023_reports_procs.sql
:r .\02-programmability\024_lookup_admin_crud_procs.sql
:r .\02-programmability\025_global_search_proc.sql
:r .\02-programmability\026_freight_parties_consignment_notes_procs.sql
:r .\02-programmability\027_capacity_volume_trip_stop_shipments_procs.sql
:r .\02-programmability\028_freight_calculation_shipment_charges_procs.sql
:r .\02-programmability\029_hired_trucks_vendors_procs.sql
:r .\02-programmability\030_empty_km_claims_procs.sql
:r .\02-programmability\031_compliance_documents_eway_bills_procs.sql

PRINT '--- 03-seed ---';
:r .\03-seed\001_lookup_seed.sql
:r .\03-seed\002_identity_seed.sql
:r .\03-seed\003_lookup_extended_seed.sql
:r .\03-seed\004_fleet_seed.sql
:r .\03-seed\005_billing_customers_seed.sql
:r .\03-seed\006_ops_seed.sql
:r .\03-seed\007_billing_invoicing_seed.sql
:r .\03-seed\008_ops_shipments_seed.sql
:r .\03-seed\009_freight_payment_type_seed.sql
:r .\03-seed\010_vendor_bill_status_seed.sql
:r .\03-seed\011_claim_status_seed.sql
:r .\03-seed\012_required_compliance_document_types_seed.sql

PRINT '--- done ---';
