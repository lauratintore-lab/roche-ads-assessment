import pandas as pd
import json
from langchain_groq import ChatGroq
from langchain_core.prompts import ChatPromptTemplate


SYSTEM_PROMPT = """
You are a Clinical Data Mapping Expert. Your role is to translate natural language questions from safety reviewers into structured JSON for Pandas filtering.

### Strategic mapping rules:
1. **Hierarchical Priority:** - If a user asks for a specific medical condition (e.g. "Nausea"), map to `AEDECOD`.
   - If a user asks for a body system (e.g. "Heart"), map to `AESOC`.
   - Use `AETERM` ONLY if the user specifies "reported term".
2. **Binary Flag Logic:** For Serious Criteria (AESDTH, AESHOSP, etc.) or AESER, if the user asks about the occurrence of the event, set `filter_value` to "Y".
3. **Fuzzy Matching:** Assume the reviewer might not use exact MedDRA terms. 
4. **Case Sensitivity:** Clinical datasets are often uppercase. Normalize `filter_value` to uppercase where appropriate.

### Semantic mapping reference:
- "Severity", "Intensity", "How bad" -> AESEV
- "Related", "Causality", "Due to drug" -> AEREL
- "Action", "Dose change" -> AEACN
- "Died", "Fatal" -> AESDTH (Value: 'Y')
- "Hospitalized" -> AESHOSP (Value: 'Y')

### Data dictionnary with a description of all the columns grouped by categories:

Category 1: Identifiers and Tracking
'STUDYID' : Study Identifier: The unique ID for the clinical trial.
'DOMAIN' : Domain Abbreviation: Always "AE" for this dataset. AE stands for Adverse Event.
'USUBJID' : Unique Subject Identifier: The unique ID for a participant across the whole study.
'AESEQ' :  Sequence Number: A counter (1, 2, 3...) to distinguish multiple AEs for one person.
'AESPID' : Sponsor-Defined ID: Links the record back to the source CRF or EDC ID.

Category 2: Standardized MedDRA dictionary
'AETERM' : Reported Term: The "verbatim" text exactly as the doctor wrote it.
'AELLT / CD' : Lowest Level Term: The most specific medical term and its numeric code.
'AEDECOD / AEPTCD' : Preferred Term (PT): The standardized medical name used for most tables (e.g., "Nausea").
'AEHLT / CD' : High Level Term: The next category up in the medical dictionary hierarchy.
'AEHLGT / CD' : High Level Group Term: An even broader grouping of related medical terms.
'AEBODSYS / CD' : Body System / Organ Class: The standardized name of the affected body system.
'AESOC / CD' : System Organ Class: The highest level of grouping (e.g., "Cardiac Disorders", "SKIN AND SUBCUTANEOUS TISSUE DISORDERS", "RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS").

Category 3: Severity, Seriousness and Outcomes
'AESEV' : Severity: How bad was it? Usually: Mild, Moderate, or Severe.
'AESER' : Serious Event: Did it cause a major medical issue? (Y/N).
'AEACN' : Action Taken: What happened to the study drug? (e.g., Dose Reduced, Withdrawn).
'AEREL' : Causality: Is the event related to the study drug? (e.g., None, Possible, Probable, Remote).
'AEOUT' : Outcome: What was the result? (e.g., Recovered, Ongoing, Fatal).

Serious Criteria - Specific Why is this serious? Flag
If 'AESER' is "Y", one of these is usually "Y" to explain why: 
'AESCAN' : Significant Cancer/Malignancy.
'AESCONG' : Congenital Anomaly or Birth Defect.
'AESDISAB' : Persistent or Significant Disability.
'AESDTH' : Results in Death.
'AESHOSP' : Requires or Prolongs Hospitalization.
'AESLIFE' : Is Life-Threatening.
'AESOD' : Occurred with an Overdose.

Category 4: Timing and Study Days
'AEDTC' : Date/Time of Collection: When the event was recorded on the form.
'AESTDTC' : Start Date/Time: When the adverse event actually began.
'AEENDTC' : End Date/Time: When the adverse event stopped.
'AESTDY' : Start Study Day: Relative day the AE started (Day 1 = First Dose).
'AEENDY' : End Study Day: Relative day the AE ended.

### Output format: 
OUTPUT A JSON OBJECT WITH THE FOLLOWING STRUCTURE:
Output ONLY a JSON object. No prose.
{{
  "target_column": "Column Name",
  "operator": "== | != | str.contains | >",
  "filter_value": "Normalized Value"
}}
Output nothing else

### Example
User: "Find all severe cardiac events"
Output: 
{{
  "target_column": "AESOC",
  "operator": "==",
  "filter_value": "CARDIAC DISORDERS"
}}
"""

API_KEY = "X" # Put your own API key here
class ClinicalTrialDataAgent:
    def __init__(self, df: pd.DataFrame, model_name: str = "openai/gpt-oss-120b"):
        self.df = df
        
        # Initialize ChatGroq. We enforce JSON mode via model_kwargs.
        self.llm = ChatGroq(
            temperature=0,
            groq_api_key=API_KEY,
            model_name=model_name,
            model_kwargs={"response_format": {"type": "json_object"}}
        )
        
    def parse_query(self, query: str) -> dict:
        """Translates a natural language query into a structured JSON dict using an LLM."""
        
        # Define the prompt structure
        prompt = ChatPromptTemplate.from_messages([
            ("system", SYSTEM_PROMPT),
            ("human", "{query}")
        ])
        
        # Create the LangChain pipeline
        chain = prompt | self.llm
        
        # Invoke the LLM
        response = chain.invoke({"query": query})
        
        # Parse the JSON string into a Python dictionary
        try:
            parsed_json = json.loads(response.content)
            return parsed_json
        except json.JSONDecodeError:
            raise ValueError(f"Failed to parse JSON from LLM response. Raw output: {response.content}")

    def dataset_filter(self, parsed_query_dict: dict) -> pd.DataFrame:
        """Applies the parsed dictionary as a filter on the Pandas DataFrame."""
        
        target_column = parsed_query_dict.get("target_column")
        filter_value = parsed_query_dict.get("filter_value")
        operator = parsed_query_dict.get("operator", "str.contains")
        
        # 1. Basic validation
        if not target_column or filter_value is None:
            raise ValueError(f"Missing essential keys in parsed dict: {parsed_query_dict}")
            
        if target_column not in self.df.columns:
            raise ValueError(f"Target column '{target_column}' not found in the DataFrame.")
            
        # 2. Extract column data for cleaner syntax
        col_data = self.df[target_column]
        
        # 3. Apply Operator Logic Safely
        try:
            if operator == "str.contains":
                # Case-insensitive partial text match
                filtered_df = self.df[col_data.astype(str).str.contains(str(filter_value), case=False, na=False)]
                
            elif operator == "==":
                # Exact text match (case-insensitive for safety)
                filtered_df = self.df[col_data.astype(str).str.upper() == str(filter_value).upper()]
                
            elif operator == "!=":
                # Exact negative text match
                filtered_df = self.df[col_data.astype(str).str.upper() != str(filter_value).upper()]
                
            elif operator in [">", "<", ">=", "<="]:
                # For numeric operations (like Study Days)
                # Coerce errors to NaN to prevent crashes if a text value sneaks in
                numeric_col = pd.to_numeric(col_data, errors='coerce')
                numeric_val = float(filter_value)
                
                if operator == ">":
                    filtered_df = self.df[numeric_col > numeric_val]
                elif operator == "<":
                    filtered_df = self.df[numeric_col < numeric_val]
                elif operator == ">=":
                    filtered_df = self.df[numeric_col >= numeric_val]
                elif operator == "<=":
                    filtered_df = self.df[numeric_col <= numeric_val]
            else:
                raise ValueError(f"Operator '{operator}' is not supported.")
                
        except ValueError as ve:
            # Catches issues like trying to turn "Severe" into a float for a ">" check
            print(f"Filter Error: {ve}")
            return pd.DataFrame(columns=self.df.columns) # Return empty dataframe on error
            
        return filtered_df

    def query_to_pandas_pipeline(self, query: str) -> pd.DataFrame:
        """End-to-end pipeline: natural language to filtered Pandas dataframe."""
        
        print(f"Original Query: '{query}'")
        
        # 1. Parse the intent
        parsed_intent = self.parse_query(query)
        print(f"LLM Parsed Intent: {json.dumps(parsed_intent, indent=2)}")

        filtered_df = self.dataset_filter(parsed_intent)
        
        # 2. Filter the dataset
        if "USUBJID" in filtered_df.columns:
            unique_ids_list = filtered_df["USUBJID"].unique()
            print(f"Number of unique subject IDs : {len(unique_ids_list)}")
            print(f"Corresponding IDs  : {unique_ids_list}")
        else:
            print(f"Number of rows matched: {len(filtered_df)}")
        
        return parsed_intent, filtered_df