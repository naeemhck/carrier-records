# Reports and dashboard

Apply migrations through `20261011001300_reports.sql`. Open Dashboard or Reports after staff sign-in. Choose the period, current office scope and optional vehicle/historical owner/search filters. Lifetime trip profit requires an explicit trip selection and includes all effective linked costs regardless of date. Monthly vehicle reports include standalone maintenance and costs on earlier trips, by expense date.

The server returns a canonical whole-filter summary plus up to 50 grouped rows per page. Paging does not change totals. Dashboard cards open the equivalent report under the same filters; recent journeys and pending arrivals use scoped trip queries. Report history and generation time explain why a current earlier-period report can change after correction. Previously issued snapshots are unaffected.

Earnings use dispatch or explicit cancellation-adjustment dates. Receipts/refunds/settlements use their payment dates. Costs use expense dates. Claims, credits, held money and recoveries are balances as of period end, or current balances for lifetime trips. Every monetary value is an exact decimal string; client display uses integer paisa/BigInt. Profit is distinct from owner settlement and customer debt.

Staff reports show assigned-office records and explicitly state that these are not complete business balances. Administrator-selected office reports are also labelled incomplete. Full administrator scope includes all business records. Trip facts inherit origin/destination access; standalone expenses and claims use their original office. Explicit unauthorized office/trip filters are denied by the backend. No client can call the raw fact helpers or read global event metadata.

An isolated benchmark in `tools/tests/t11_reports.py` requires an empty loopback backend. It creates twelve months at 1,000 trips/month, twenty vehicles and five distinct managed staff sessions, then measures HTTP summaries and paginated screens. Fixtures and logs remain ignored and are cleaned afterwards. Never run it against operational data. Local measurements are not a hosted-network service guarantee.

Recipient customization follows T12. Document issuance, PDF/Excel files, printing, release distribution, hosted quotas and backup status retain their later task gates.
