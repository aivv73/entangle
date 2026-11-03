# Upload verification design

The three design candidates compared an extension of the existing production driver, separate small and large executables, and a standalone native verifier. All rejected a generic scenario interpreter. The coordinator and independent design reviewer selected explicit production scenarios plus the standalone native verifier.

The production interface rejects oversized writes before native dispatch. Direct native rejection therefore needs a separate call path. The selected standalone accepts only an entry, creates every resource itself, returns no resource, and exposes no helper that accepts a device, buffer, or allocation. Its complete source hash is mandatory. Raw writer symbols remain forbidden to ordinary sources.

The production and native scenarios use a buffer of limit plus two bytes, transfer at offset one, and compare both adjacent guards. Successful exact-limit reads compare every byte and the list length. Production rejection checks consume bounded readback chunks. The native scenario keeps raw operations in its single resource-owning entry function.

The design combines the first candidate's standalone native boundary with the second candidate's two guards and complete byte comparisons. The third candidate contributed the distinction between scalar ABI roundtrips and flattened buffer fields. A separate large production executable was unnecessary after actual runs completed within the existing deadline.

Implementation review strengthened two observations. Rejected payloads now invert every byte. The flattened probe now uses distinct fields and an exact high-limb expectation. The adjacent verification record contains their rationale and executed results.
