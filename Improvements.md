The biggest improvement would be to explain when each recommendation applies. Several pages turn a useful default or personal architecture choice into an absolute rule. There are also a few examples that would teach readers the wrong behavior or fail when copied.

The most consequential corrections are below, followed by improvements to the other topics already covered.

<!-- 1. The DAX context explanation needs substantial correction

See context.md (semantic_model/context.md:9).

The row-context section uses this example:

_rowContext = SUM(Sales[Quantity])

This does not clearly demonstrate row context. The screenshot shows a calculated column containing the total quantity on every row. That is useful, but it illustrates that having a current row does not automatically filter an aggregation to that row.

A clearer explanation would introduce these separately:

-- Calculated column: reads the current row
Quantity This Row = Sales[Quantity]

-- Measure: sums rows visible in the current filter context
Total Quantity = SUM(Sales[Quantity])

Then explain that calculated columns and iterators provide row context, while report selections provide filter context. This distinction is fundamental to understanding DAX. (learn.microsoft.com)

The context-transition section also reverses the relationship between the concepts. CALCULATE converts an existing row context into filter context. Putting an iterator inside CALCULATE is not the general definition of context transition. A measure evaluated inside an existing row context receives automatic context transition. (learn.microsoft.com)

Consequently, the statement that “a measure referencing another measure” triggers the illustrated duplicate counting is too broad. An ordinary measure alias has no row context to convert.

Suggested improvement: Make the calculation location explicit beside every example: calculated column, measure, or expression inside an iterator. Keep the duplicate-row screenshot, but explain that it is a specific calculated-column example. Present a unique row identifier as one possible remedy for that requirement, rather than a general cure for incorrect totals. -->

<!-- 2. The native-query folding example is incorrect

See query_folding.md (power_query/query_folding.md:32).

The example places EnableFolding = true inside the options for Sql.Database. Microsoft’s documented pattern places it in the fourth argument of Value.NativeQuery. (learn.microsoft.com)

A better example would be:

let
    Source = Sql.Database("ServerName", "DatabaseName"),
    Sales = Value.NativeQuery(
        Source,
        "SELECT OrderID, Amount FROM dbo.Sales",
        null,
        [EnableFolding = true]
    ),
    PositiveSales = Table.SelectRows(Sales, each [Amount] > 0)
in
    PositiveSales

Explain what readers should observe: the final filter can be folded back into the database query when the connector and query support it.

This is a high-priority correction because the current example looks ready to copy. -->

<!-- 3. Query folding is described as too strictly sequential

See the same page at line 19 (power_query/query_folding.md:19).

The explanation says that one non-foldable step breaks folding for every subsequent step. This is a useful warning, but it is not a complete description of evaluation. Power Query optimizes the query and can reorder steps. Folding depends on the connector, transformations, and resulting evaluation plan. (learn.microsoft.com)

I would replace the absolute statement with:

> A non-foldable transformation can cause more work to run in the Power Query engine. Filter rows and select required columns early, then inspect folding rather than assuming the applied-step order fully describes execution.

Add a short explanation of how to inspect the generated query or diagnostics. Also distinguish tools available in Desktop from folding indicators and query plans available in Power Query Online. (learn.microsoft.com) -->

<!-- 4. The advice against separate date-role dimensions is misleading

See star_schema.md (semantic_model/star_schema.md:19).

The page discourages separate Dim_Date_Order and Dim_Date_Ship tables and recommends calculation groups instead. These designs solve different reporting requirements.

For example:

| Reporting requirement | Design to consider |
|---|---|
| Switch one date selection between order date and ship date | One date dimension, an inactive relationship, and measures or calculation items |
| Filter order date and ship date independently | Separate dimensions with active relationships |
| Security filtering must follow a relationship | Carefully designed active relationships |

Microsoft recommends active relationships where possible and explicitly describes duplicating role-playing dimensions when independent filtering is needed. RLS filters do not propagate through inactive relationships, even when a measure uses USERELATIONSHIP. (learn.microsoft.com)

Suggested improvement: Present both designs with a concrete question each one answers. Separate semantic-model tables can still originate from one maintained date table upstream, so their existence need not mean duplicated calendar-maintenance logic. -->

<!-- 5. The Direct Lake guide confuses report connections with storage modes

See power_bi.md (connection/power_bi.md:3).

The screenshot under “Direct Lake” shows Get data → Power BI semantic models. It demonstrates connecting a report to an existing model. It does not establish that the model uses Direct Lake.

Explain these as two separate choices:

- Report connection: Which semantic model supplies the report?
- Model storage: How does that model access its tables?

Direct Lake is a semantic-model table storage mode. Its underlying Delta data resides in OneLake, while queries commonly use an in-memory column cache. The current “all data remains in the cloud” explanation omits that mechanism. (learn.microsoft.com)

Suggested improvement: Rename the screenshot section “Connect to an existing semantic model.” Add a storage-mode comparison separately. Explain why Direct Lake is preferred for the architecture described here, including its requirements and limitations, rather than marking it universally recommended. -->

<!-- 6. Explicit measures should not be presented as a security boundary

See implicit_explicit.md (governance/implicit_explicit.md:12).

The salary example illustrates an important risk: users can sometimes inspect more detail than a visual initially displays. However, the explanation could lead readers to believe that replacing an implicit measure with an explicit measure protects confidential underlying data.

The stronger recommendation is:

> Use explicit measures to define approved calculations consistently. Protect sensitive data through permissions and the appropriate data-security design.

RLS restricts rows; OLS addresses restricted columns and metadata. RLS does not provide “summary access only,” and it does not restrict workspace Admins, Members, or Contributors. (learn.microsoft.com)

Suggested improvement: Keep the screenshot as an illustration of unintended detail exposure. Then explain the actual controls needed for the salary scenario. Add consistency, controlled aggregation, reuse, and Excel compatibility to the reasons for explicit measures. -->

<!-- 7. Referencing a query does not transfer its RLS protection

See functions.md (power_query/functions.md:18).

The example references a detailed table protected by RLS to produce a summary table. It says this guarantees cross-table consistency, but leaves an important question unanswered: how is the summary table secured?

Power Query references reuse transformation logic. RLS operates on the semantic model and its filtering relationships. Readers should not infer that a summary inherits security merely because its query references a secured table. (learn.microsoft.com)

Suggested improvement: Either use a non-security example to teach Reference versus Duplicate, or explicitly describe the summary table’s intended access and security design.

The existing warning about repeated source retrieval is valuable. Develop it further by explaining that a reference is not a guaranteed shared materialized result. (learn.microsoft.com) -->

<!-- 8. The deployment explanation contains direct contradictions

See deployment.md (architecture/deployment.md:6).

The page states that there is no Test workspace, but its configuration includes "test". It also defines "dev_n" twice, making the example ambiguous instead of representing two distinct development environments.

Meanwhile, architecture/index.md (architecture/index.md:29) proposes changing to Test and Prod only.

A reader cannot determine which design to follow.

Suggested improvement:

- Describe the current architecture consistently.
- Label the Test/Prod-only approach as a proposed alternative.
- Give each example environment a unique name.
- Explain which branch each workspace follows.
- Explain where validation occurs, regardless of whether that workspace is named Dev or Test.

The argument that a Test workspace necessarily creates a bottleneck is also too absolute. State why your chosen workflow avoids a shared Test stage and what tradeoffs you accept.

Similarly, validated source data does not establish that a report’s calculations, relationships, filters, or layout are correct. The domain-workspace explanation should describe how analysts validate those assets before publication. -->

<!-- 9. The deployment automation described is ahead of the included examples

The guide says merging into main automatically deploys changes and updates connections. The included example raplace_id.yaml (architecture/scripts/github/workflows/raplace_id.yaml:1) instead handles a particular sandbox branch merging into dev.

It also calls .github/scripts/replace_ids.py, while the example script in this repository is named and located differently.

That can be acceptable for a template, but it must be explained.

Suggested improvement: Label each component as implemented, example to adapt, or planned. List the required files, repository variables or secrets, and expected deployment result.

The autobinding paragraph also needs conditions. Fabric supports notebook binding across environments in supported Git and deployment scenarios, but the relevant settings and dependencies matter. (learn.microsoft.com)

Finally, expand “simultaneous PRs” into an ordered release example. For a new report column, I would recommend documenting: deploy the compatible data change, confirm it is available, then deploy the dependent model and report. -->

<!-- 10. The medallion layout should be presented as your selected design

See medallion.md (architecture/medallion.md:6).

The page says exactly four lakehouses ensure optimal governance. That conclusion is stronger than the explanation supports.

The four-layer design can be useful, but readers need to understand why you selected it. For example: preserving incoming files, recording source changes, standardizing data, and publishing shared analytical tables.

There is also a terminology mismatch between “single workspace per environment” here and the multiple development workspaces in the deployment guide.

Suggested wording:

> This design uses four lakehouses within each deployed data environment. Development environments can be replicated across workspaces to isolate parallel work.
t.
That describes the intended structure without implying that four physical lakehouses are a universal requiremen -->

<!-- 11. Landing and Bronze need clearer retention and history semantics

See medallion.md (architecture/medallion.md:11).

Landing snapshots are overwritten, while Bronze is described as storing all source data in its native state for an audit trail. Elsewhere, Bronze only receives new or changed snapshot rows.

Those statements leave several unanswered questions:

- Are original snapshots retained anywhere?
- Is Bronze an unchanged extract or a change-history table?
- How are deleted source records detected?
- What happens if the same ingestion runs twice?
- How are corrections to older records represented?

Suggested improvement: Walk through one work order across three snapshots: created, updated, and absent. Show what is retained in Landing and what is appended to Bronze at each stage.

This would make the existing architecture much easier to implement correctly. -->

<!-- 12. Business keys and surrogate keys need a firmer distinction

See tables_structure.md (architecture/tables_structure.md:10).

The page says users can choose their preferred primary key and define their own granularity. For a historical dimension, that is misleading: the business key can repeat across versions, while the surrogate key identifies a particular dimension row.

Microsoft’s dimensional guidance describes surrogate keys as unique row identifiers and recommends compact integer types where appropriate. (learn.microsoft.com)

Suggested improvement: Explain:

> The business key identifies the source entity. The surrogate key identifies the dimension row or historical version referenced by a fact.

Readers can group several versions by business identity, but the relationship must still preserve the intended historical meaning.

The choice to store every key as text also needs justification. If deterministic hashes are important to your pipelines, document the reason and tradeoffs instead of calling text universally more flexible. -->

<!-- 13. The SCD explanation needs to show how facts find the right version

The historical rows and deletion note in tables_structure.md (architecture/tables_structure.md:12) are useful, but the main analytical step is missing.

For a Type 2 dimension, a fact must normally find the version applicable at the event time, rather than simply joining to the current business-key match. Microsoft explicitly describes this time-based lookup. (learn.microsoft.com)

Suggested improvement: Add an example where an employee changes department:

> Sales before the transfer reference the earlier employee version. Sales after the transfer reference the new version.

Then define the validity boundaries precisely. I would recommend an explicit convention such as “start inclusive, end exclusive” so adjacent versions cannot overlap.

Also consider renaming SC_Active to Is_Current_Version. Your note already explains that a current deletion record is not an active business entity; the current column name encourages that confusion. -->

<!-- 14. Some fact-table terminology needs correction

See tables_structure.md (architecture/tables_structure.md:27).

The fact-table example has several measure columns, while the text mandates “long format.” That example can be perfectly reasonable, but the term needs defining. Explain whether you mean rows of business events or an unpivoted metric-name/metric-value structure.

The section also calls copied dimension business keys “degenerate dimensions.” A typical degenerate dimension is an identifier retained in the fact without its own dimension table, such as an order number. Copying an existing dimension’s business key for troubleshooting is a separate design choice. (learn.microsoft.com)

Suggested improvement: Explain the purpose of each retained key and which columns should be exposed to report authors.

The paragraph suggesting wrong relationships will immediately reveal themselves should also be removed. Correctness should be demonstrated by relationship and integrity checks; the document provides no basis for relying on visibly incorrect numbers. -->

<!-- 15. Missing-dimension handling needs a recovery step

See tables_structure.md (architecture/tables_structure.md:45).

Defaulting an unresolved dimension to -1 keeps the fact row available, but the explanation stops there.

I would add:

> Retain the unresolved business key and record why the lookup failed. When the dimension becomes available, revisit the affected facts according to the historical matching rules.

Otherwise readers may permanently leave valid transactions categorized as unknown.

Consider separating “not applicable,” “unknown,” and “not loaded yet.” These represent different situations and may need different reporting treatment. Microsoft’s dimension guidance includes missing and inferred-member audit concepts. (learn.microsoft.com) -->

<!-- 16. The date/time guide has useful examples but needs corrections and exceptions

See date_time_values.md (architecture/date_time_values.md:15).

The UTC recommendation needs a prerequisite: the source timezone or offset must be known. A repeated local time during a daylight-saving transition can represent two different instants. Converting an ambiguous value does not recover information the source omitted. (docs.python.org)

I would explain the distinction between the stored instant and the local business date used for reporting.

There are also concrete example problems:

- The fact-table header has eight columns, but its separator has five.
- The second UTC timestamp advances by one second while the local timestamp does not.
- Integer time keys are shown with leading zeros without explaining display formatting.
- Rolling-date examples implicitly use July 14, 2026 as their reference date.
- The four-week aggregation threshold is presented without a reason tied to reporting requirements.

The Is_Peak_Hour example also needs scope. If peak classification depends on weekdays, holidays, seasons, or region, a time-of-day table alone cannot represent that rule. -->

17. Power Query advice should prioritize shared logic and execution behavior

See power_query/index.md (power_query/index.md:2), minimize_power_query.md (power_query/minimize_power_query.md:3), and minimizing_steps.md (power_query/minimizing_steps.md:3).

The strongest existing point is that duplicated transformations across reports create maintenance problems. Preserve that argument.

However, “minimize Power Query” and “minimize applied steps” are weak objectives by themselves. Folded M transformations can execute upstream, and several clearly named steps may be more maintainable than one compressed expression. Microsoft emphasizes early filtering, appropriate types, documentation, and modular queries. (learn.microsoft.com)

Suggested wording:

> Prefer shared transformations for logic used by multiple consumers. When using Power Query, reduce unnecessary data movement, preserve folding where possible, and keep the transformation sequence readable.

The claim that a database change is “instantly reflected” in every report should also be qualified. Explain the expected refresh or update behavior for the connection mode being used. (learn.microsoft.com)

18. Add a clear explanation of where calculations belong

This would connect dax.md (semantic_model/dax.md:5) with functions.md (power_query/functions.md:61). The existing power_query_vs_dax.md (power_query/power_query_vs_dax.md) is empty.

I would explain the choices using existing topics:

| Calculation requirement | Recommended starting point |
|---|---|
| Shared cleansing, unit conversion, or historical matching | Upstream transformation |
| A stored attribute needed for grouping or filtering | Source transformation or supported calculated-column approach |
| A result that responds to report selections | DAX measure |
| Repeated transformations of several measures | Calculation group |

Measures are evaluated in context; calculated columns store row values. That difference should drive the explanation. (learn.microsoft.com)

The DAX formatting example also needs simplifying. It contains typographic subtraction characters and combines growth percentages with monetary values in a deliberately random expression. Use a meaningful year-over-year example so readers can assess both syntax and business meaning.

For variables, add that storing a result does not cause it to be reevaluated under later filters. This is an important practical limitation missing from the current performance explanation. (learn.microsoft.com)

19. Calculation groups and time intelligence need operating boundaries

See calculation_groups.md (semantic_model/calculation_groups.md:3).

The examples are a useful introduction. Replace “any measure” with an explanation of which measures should receive each transformation. A growth calculation intended for sales may be inappropriate for a color-returning measure or an already calculated percentage.

Add a small example of restricting eligible measures, explain precedence when several groups are used, and rename the relationship items from Active/Inactive to Order Date/Ship Date. Those names describe their business meaning. (learn.microsoft.com)

In time_intelligence.md (semantic_model/time_intelligence.md:12), “turn off automatic time intelligence” should say disable Auto date/time. Disabling hidden automatic date tables does not disable DAX time-intelligence calculations. (learn.microsoft.com)

Then explain the date-table requirements and identify the time-intelligence approach your examples use. Add expected behavior for incomplete periods and fiscal calendars. (learn.microsoft.com)

20. Governance pages need to explain the layers of access

See app.md (governance/app.md:3), entraid.md (governance/entraid.md:5), and rls.md (governance/rls.md:1).

The RLS page ends mid-example and is not linked from the governance overview. Meanwhile, other pages already rely on readers understanding RLS.

I would complete that explanation before expanding governance further. Use one person’s access to show the separate questions: which reports they can open, which model capabilities they have, and which rows or columns they can access. Workspace roles and RLS have different effects. (learn.microsoft.com)

The Entra page also assumes dynamic groups mean employees’ managers control access. That depends on the organization’s rules and attribute-maintenance process. Describe it as your observed organizational arrangement and explain who owns the group rules.

The privacy-level table is broadly aligned with Microsoft’s explanation. Its example should say sensitive values may be sent to another source depending on evaluation, rather than claiming this always happens when both sources are Organizational. Distinguish privacy classifications from the separate option to ignore them. (learn.microsoft.com)

21. Connection guides need prerequisites and more text around screenshots

See excel.md (connection/excel.md:5), python.md (connection/python.md:9), and sql.md (connection/sql.md:32).

The Excel guide describes semantic-model results as limited to PivotTables. Current supported Excel experiences also include connected tables. Explain both, together with the relevant permissions and prerequisites. (learn.microsoft.com)

For Python, document dependencies per example. The GraphQL script imports requests and azure.identity, but those prerequisites are not supplied in its section. “Azure CLI is required for all solutions” should be narrowed to the included local scripts that use AzureCliCredential.

For SQL, explain that a lakehouse SQL analytics endpoint provides a read-only T-SQL surface over lakehouse Delta tables. A Warehouse is a different item, even though both support SQL connectivity. (learn.microsoft.com)

Across these guides, add text stating what to enter, where to find it, and what successful output looks like. Screenshots should support those instructions.

22. Ownership guidance should describe the script’s exact scope

See ownership.md (architecture/ownership.md:4).

The instructions mix prerequisites: they mention AzureAD or Microsoft.Graph installation, then show an Azure CLI command. The linked takeover script instead uses MicrosoftPowerBIMgmt.

Explain which tool is required for each operation.

Also narrow “take ownership of any item.” The script calls the semantic-model takeover endpoint; ownership behavior for other Fabric items has separate limitations. (learn.microsoft.com)

The note explicitly stating that automated takeover is not yet integrated into CI/CD is good documentation practice. Apply that same implemented/planned distinction elsewhere.

I would also explain that model ownership, connection credentials, permissions, and refresh behavior need separate attention. The recommendation should describe how continuity is achieved rather than implying that ownership transfer alone resolves every refresh dependency.

23. Reporting recommendations need measurable goals and accessibility

See performance.md (reporting/performance.md:5), design.md (reporting/design.md:14), and background.md (reporting/background.md:5).

The two-second limit and maximum of six to eight visuals should be labeled as your design targets. The repository does not provide evidence for a universal adoption threshold.

Expand Performance Analyzer beyond opening the pane. Explain how query duration, visual display, and other waiting or processing time suggest different problems. (learn.microsoft.com)

For design, treat F/Z reading patterns and the blink test as heuristics. The broad statement about opposite color meanings “in Asia” should be narrowed or replaced with a specific, sourced audience example.

Add accessibility to the existing color and background guidance: understandable labels, sufficient contrast, alternative text, and information conveyed through more than color alone. (learn.microsoft.com)

For backgrounds, I would recommend exporting a correctly sized image rather than taking a screenshot. Keep essential headings and instructions as accessible report elements where appropriate.

24. Theme documentation needs schema guidance and dated observations

See find_themable_features.md (reporting/Theme_Template/find_themable_features.md:5).

The file extension .pbid should be .pbip. The path description should identify the actual report-definition file rather than ending at an unclear visual location. Microsoft describes PBIP projects and inspecting formatted visuals through PBIR files. (learn.microsoft.com)

The claim that anything under a data object cannot be themed is too broad to use as the sole decision rule. Explain that report definitions and theme files have different structures, then verify candidate properties against the theme schema. (learn.microsoft.com)

The bug and non-themeable pages should record the tested Desktop version, visual type, date, and current verification status. I did not validate those observations in Desktop.

There is also a useful improvement to conditional_formatting.md (reporting/conditional_formatting.md:7): Microsoft now documents named theme colors returned from measures for field-value formatting. That could reduce duplicated hexadecimal colors between your theme and formatting measures. (learn.microsoft.com)

25. Documentation navigation and validation need alignment

The file and image references resolve in the local filesystem, but several references need attention:

- #direct-lake-anbefalt does not match the English heading.
- #reading-patterns does not match “Layout and Reading Patterns.”
- #slicerslicer does not match “Slicer.”
- Some paths use readme.md or Theme_template while the stored names use different capitalization.

The local link checker skips heading anchors, so those inconsistencies are outside its current coverage.

There is also a direct workflow mismatch: check_links.yml (.github/workflows/check_links.yml:40) calls test/markdown_links.py, while the checker is tests/test_markdown_links.py (tests/test_markdown_links.py:1).

The checker’s own explanation says it can run without pytest, but it imports pytest unconditionally. Both the workflow and the explanation should match the actual file.

For readability, I would give each guide the same basic progression: purpose → recommendation → reason → conditions → example → expected result. Correct recurring spelling errors after the technical corrections. That order will improve the explanations more than grammar editing alone.

Recommended order of work: correct DAX context and folding first; then relationships and security; then deployment consistency; then improve examples, prerequisites, and reporting guidance.

Assumptions: I treated your request as a review of the current local contents, with suggestions for existing topics rather than an instruction to rewrite the files. This was a document and source review; the connection, deployment, takeover, and Desktop examples were not executed.