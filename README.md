Title

Executve Summary - problem, solution, next steps, number impact
	
Business problem
Fintex, uma SaaS B2B de gestão financeira para PMEs, lançada em Jan 2022, com crescimento forte até meados de 2023, depois uma fase de contração por causa de pricing, e recuperação via produto em 2024.

FicheiroLinhasConteúdo
plans.csv4Starter £49, Growth £129, Scale £299, Enterprise £799
users.csv5.980Sign-up, canal, indústria, país, tamanho empresa
subscriptions.csv5.980Plano, billing cycle, status, MRR, churn reason
payments.csv31.967Cada cobrança com status (succeeded/failed/refunded)
events.csv17.823Funil completo: signed_up → activated → converted → upgraded

A história que os dados contam (propositadamente incorporada):
MRR a crescer de ~£50k (Jan 2022) até ~£800k (Dez 2024)
Churn spike em Jul–Dez 2023 (churn 2× acima do normal) — causa: pricing, identificável pela coluna cancel_reason
Queda de sign-ups no mesmo período, visível em users.acquisition_channel
Recuperação H1 2024 com expansão via upgrades (20% dos Growth/Scale fazem upgrade)
Taxa de activação no funil de ~50%, com drop-off principal entre onboarding_step2 e activated
Churn total de ~35% das subscrições ao longo dos 3 anos


Methodology

Skills
github pr, dbt core, sqlfluff precommit hook, github actions	
Results & Business recommnedations

Next steps# revenue_product_analysis


Answer the data questions: 📊 Revenue Analysis How has revenue evolved over time (MRR/ARR growth)? What are the main drivers of revenue (new, expansion, churn)? What is the revenue churn rate and how is it impacting growth? Which customer segments generate the most revenue? What is the average revenue per user (ARPU) and how does it vary? What is the customer lifetime value (LTV)? Are there any seasonality patterns or trends in revenue? 🔍 Product Funnel Analysis What is the conversion rate at each stage of the funnel? Where are the biggest drop-offs occurring? How long does it take users to reach activation (time to first value)? How does activation impact user retention? Which user actions are most correlated with conversion? What differentiates users who convert vs those who don’t? What is the retention rate over time (cohort analysis)? Which acquisition channels or segments convert best?
