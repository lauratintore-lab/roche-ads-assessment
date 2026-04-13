from agent import ClinicalTrialDataAgent
import pandas as pd
import json
from langchain_groq import ChatGroq
from langchain_core.prompts import ChatPromptTemplate

# --- LIVE LLM EXECUTION ---
def run_llm_pipeline():

    df = pd.read_csv("adae.csv")

    agent = ClinicalTrialDataAgent(
    df=df)

    test_queries = [
        "Find all the patients that were hospitalized due to an adverse event."
    ]

    print("Running LIVE queries against the LLM...\n")

    for query in test_queries:
        print("-" * 60)

        agent.query_to_pandas_pipeline(query)

# --- OFFLINE / MOCKED EXECUTION ---
def run_hardcoded_pipeline():
    df = pd.read_csv("adae.csv")
        
    agent = ClinicalTrialDataAgent(
    df=df)

    mocked_responses = {
        "Give me the subjects who had an adverse event probably related to the study drug.": {
            "target_column": "AEREL",
            "operator" : "==",
            "filter_value": "PROBABLE"
        },
        "Find all the patients that were hospitalized due to an adverse event.": {
            "target_column": "AESHOSP",
            "operator" : "==",
            "filter_value": "Y"
        },
        "Show me all patients who had adverse events not related to the Skin body system.": {
            "target_column": "AEBODSYS",
            "operator" : "!=",
            "filter_value": "SKIN"
        }
    }

    print("Running HARDCODED queries (LLM unplugged)...\n")

    for query, hardcoded_intent in mocked_responses.items():
        print("-" * 60)
        print(f"Original Query: '{query}'")
        print(f"Hardcoded Intent: {hardcoded_intent}")
        
        # Bypass the LLM entirely and pass the hardcoded dictionary directly to the filter
        filtered_df = agent.dataset_filter(hardcoded_intent)
        
        unique_ids_list = filtered_df["USUBJID"].unique()

        print(f"Number of unique subject IDs : {len(unique_ids_list)} \n Corresponding IDs  : {unique_ids_list}")

if __name__ == "__main__":

    # Run this line if you can plug your own Groq API KEY
    #run_llm_pipeline()

    # Run this line if you want to see the hardcoded version of gpt-oss-120b answers.
    run_hardcoded_pipeline()