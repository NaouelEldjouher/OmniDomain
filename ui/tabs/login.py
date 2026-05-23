"""OmniDomain — Login (email only, no password)"""
import streamlit as st
from core.db import get_or_create_user


def render():
    # If already logged in, let app.py continue
    if st.session_state.get("logged_in"):
        return True

    st.markdown("## 🧬 Welcome to OmniDomain")
    st.markdown("Please log in to access the genomics platform.")

    with st.form("login_form"):
        email = st.text_input("Email Address *")
        name = st.text_input("Name (Optional)")
        org = st.text_input("Organisation (Optional)")

        submit = st.form_submit_button("Enter Platform", type="primary")

        if submit:
            if not email or "@" not in email:
                st.error("Please enter a valid email address.")
                return False

            try:
                # 🚀 Call your new PostgreSQL database!
                user_id = get_or_create_user(email=email, name=name, org=org)

                # Save user data to the session state
                st.session_state["logged_in"] = True
                st.session_state["user_email"] = email
                st.session_state["user_name"] = name or email.split('@')[0]
                st.session_state["user_id"] = user_id

                st.success("Login successful!")
                st.rerun()  # Refresh the page to bypass the login gate

            except Exception as e:
                st.error(f"Database error: {str(e)}")
                return False

    return False