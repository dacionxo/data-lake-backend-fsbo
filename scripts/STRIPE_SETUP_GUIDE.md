# Stripe Pricing Integration Setup Guide

This guide will walk you through setting up Stripe to handle payments for your pricing page.

## 📋 Prerequisites

- A Stripe account (sign up at https://stripe.com)
- Access to your Stripe Dashboard
- Your Next.js application running locally or deployed

## 🚀 Step 1: Get Your Stripe API Keys

1. Go to [Stripe Dashboard](https://dashboard.stripe.com)
2. Make sure you're in **Test mode** for development (toggle in the top right)
3. Navigate to **Developers** → **API keys**
4. Copy your keys:
   - **Publishable key** → This will be `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`
   - **Secret key** → This will be `STRIPE_SECRET_KEY` (keep this secret!)

### Test Mode vs Live Mode

- **Test Mode**: Use test card numbers (e.g., `4242 4242 4242 4242`) - no real charges
- **Live Mode**: Real payments - switch when ready for production

## 🛍️ Step 2: Create Products and Prices in Stripe

You need to create products and prices for each billing tier:

### 2.1 Create Professional Plan (Monthly)

1. Go to **Products** → **Add product**
2. Fill in:
   - **Name**: `Professional Plan (Monthly)`
   - **Description**: `Professional plan billed monthly at $175/month`
   - **Pricing model**: `Standard pricing`
   - **Price**: `$175.00`
   - **Billing period**: `Monthly`
   - **Currency**: `USD`
3. Click **Save product**
4. **Copy the Price ID** (starts with `price_...`) → This is `NEXT_PUBLIC_STRIPE_PROFESSIONAL_MONTHLY_PRICE_ID`

### 2.2 Create Professional Plan (Annual)

1. Go to **Products** → **Add product**
2. Fill in:
   - **Name**: `Professional Plan (Annual)`
   - **Description**: `Professional plan billed annually at $150/month`
   - **Pricing model**: `Standard pricing`
   - **Price**: `$1,800.00` (or set as recurring $150/month billed annually)
   - **Billing period**: `Yearly` (or `Monthly` with "Billed annually" option)
   - **Currency**: `USD`
3. Click **Save product**
4. **Copy the Price ID** (starts with `price_...`) → This is `NEXT_PUBLIC_STRIPE_PROFESSIONAL_ANNUAL_PRICE_ID`

> **Note**: For annual billing, you can either:
> - Create a yearly recurring price ($1,800/year)
> - Create a monthly recurring price ($150/month) with "Billed annually" option
> 
> Stripe will handle the billing automatically based on your choice.

### 2.3 (Optional) Create Organization Plan

If you want to handle Organization plan payments through Stripe (instead of "Talk to Sales"):

1. Create products similar to above for Organization tier
2. Set prices: $300/month or $250/month (billed annually)
3. Copy the Price IDs

## 🔧 Step 3: Set Environment Variables

### For Local Development

Create or update `.env.local` in your project root:

```env
# Stripe Configuration
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_PUBLISHABLE_KEY_HERE
STRIPE_SECRET_KEY=sk_test_YOUR_SECRET_KEY_HERE

# Stripe Price IDs
NEXT_PUBLIC_STRIPE_PROFESSIONAL_MONTHLY_PRICE_ID=price_YOUR_MONTHLY_PRICE_ID_HERE
NEXT_PUBLIC_STRIPE_PROFESSIONAL_ANNUAL_PRICE_ID=price_YOUR_ANNUAL_PRICE_ID_HERE
```

### For Production (Vercel)

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Select your project
3. Go to **Settings** → **Environment Variables**
4. Add each variable:
   - `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` (use your **Live** publishable key)
   - `STRIPE_SECRET_KEY` (use your **Live** secret key)
   - `NEXT_PUBLIC_STRIPE_PROFESSIONAL_MONTHLY_PRICE_ID` (use your **Live** price ID)
   - `NEXT_PUBLIC_STRIPE_PROFESSIONAL_ANNUAL_PRICE_ID` (use your **Live** price ID)
5. Make sure to select the correct **Environment** (Production, Preview, Development)

> **Important**: 
> - Use **Test** keys and price IDs for development/preview
> - Use **Live** keys and price IDs for production
> - Never commit your `.env.local` file to git

## 🔄 Step 4: Configure Webhook Endpoint (Optional but Recommended)

Webhooks allow Stripe to notify your app about payment events (subscriptions, cancellations, etc.).

### 4.1 Set Up Webhook in Stripe

1. Go to **Developers** → **Webhooks**
2. Click **Add endpoint**
3. Enter your endpoint URL:
   - **Local**: Use [Stripe CLI](https://stripe.com/docs/stripe-cli) to forward webhooks
   - **Production**: `https://yourdomain.com/api/stripe/webhook`
4. Select events to listen to:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
5. Copy the **Signing secret** (starts with `whsec_...`)

### 4.2 Add Webhook Secret to Environment Variables

Add to `.env.local`:
```env
STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## ✅ Step 5: Test the Integration

### 5.1 Test Locally

1. Make sure your `.env.local` has all Stripe variables
2. Restart your dev server:
   ```bash
   npm run dev
   ```
3. Navigate to `/pricing`
4. Click "Buy now" on the Professional plan
5. Use Stripe test card: `4242 4242 4242 4242`
   - Expiry: Any future date (e.g., `12/34`)
   - CVC: Any 3 digits (e.g., `123`)
   - ZIP: Any 5 digits (e.g., `12345`)

### 5.2 Verify Checkout Flow

- You should be redirected to Stripe Checkout
- After successful payment, you should be redirected to `/dashboard?success=true`
- Check your Stripe Dashboard → **Payments** to see the test payment

## 🎯 How It Works

### Payment Flow

1. User clicks "Buy now" on pricing page
2. `handleUpgrade()` function is called with the price ID
3. Frontend calls `/api/stripe/create-checkout-session`
4. API route creates a Stripe Checkout Session
5. User is redirected to Stripe Checkout
6. After payment, user is redirected back to your app

### Code Structure

- **Frontend**: `components/PricingPage.tsx` - Handles UI and calls API
- **API Route**: `app/api/stripe/create-checkout-session/route.ts` - Creates checkout session
- **Webhook**: `app/api/stripe/webhook/route.ts` - Handles Stripe events

## 🔍 Troubleshooting

### "Price ID is required" error

- Check that your environment variables are set correctly
- Verify the price IDs exist in your Stripe dashboard
- Make sure you're using the correct price IDs (test vs live)

### "Invalid API key" error

- Verify your Stripe keys are correct
- Check you're using test keys in test mode and live keys in production
- Ensure no extra spaces or quotes in environment variables

### Checkout redirects but shows error

- Check your `NEXT_PUBLIC_APP_URL` is set correctly
- Verify success/cancel URLs in the API route match your domain
- Check Stripe Dashboard → **Developers** → **Logs** for detailed errors

### Webhook not receiving events

- Verify webhook endpoint URL is correct
- Check webhook signing secret is set in environment variables
- Use Stripe CLI for local testing: `stripe listen --forward-to localhost:3000/api/stripe/webhook`

## 📚 Additional Resources

- [Stripe Checkout Documentation](https://stripe.com/docs/payments/checkout)
- [Stripe Testing Guide](https://stripe.com/docs/testing)
- [Stripe Webhooks Guide](https://stripe.com/docs/webhooks)
- [Stripe CLI Documentation](https://stripe.com/docs/stripe-cli)

## ✅ Checklist

- [ ] Stripe account created
- [ ] API keys copied (publishable and secret)
- [ ] Products and prices created in Stripe
- [ ] Price IDs copied
- [ ] Environment variables set in `.env.local`
- [ ] Environment variables set in Vercel (for production)
- [ ] Test payment successful
- [ ] Webhook endpoint configured (optional)
- [ ] Webhook secret added to environment variables (optional)

## 🚨 Security Notes

1. **Never commit** `.env.local` to version control
2. **Never expose** your secret key in client-side code
3. **Use test mode** for development
4. **Verify webhook signatures** in production
5. **Use HTTPS** in production (required by Stripe)

