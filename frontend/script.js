document.addEventListener('DOMContentLoaded', () => {
    const requestForm = document.getElementById('request-form');
    const verifyForm = document.getElementById('verify-form');
    const requestBtn = document.getElementById('request-btn');
    const verifyBtn = document.getElementById('verify-btn');
    const messageBox = document.getElementById('message');
    const backToRequest = document.getElementById('back-to-request');

    const API_REQUEST = '/otp/request';
    const API_VERIFY = '/otp/verify';

    let currentEmail = '';

    function showMessage(text, type) {
        messageBox.textContent = text;
        messageBox.className = `message-box ${type}`;
        setTimeout(() => {
            messageBox.classList.add('hidden');
        }, 5000);
    }

    function toggleLoading(btn, isLoading) {
        if (isLoading) {
            btn.classList.add('loading');
            btn.disabled = true;
        } else {
            btn.classList.remove('loading');
            btn.disabled = false;
        }
    }

    requestForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        const name = document.getElementById('name').value;
        const email = document.getElementById('email').value;
        const city = document.getElementById('city').value;

        toggleLoading(requestBtn, true);

        try {
            const response = await fetch(API_REQUEST, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ email, name, city }),
                credentials: 'omit'
            });

            const data = await response.json();

            if (response.ok) {
                currentEmail = email;
                document.getElementById('email-verify').value = email;

                requestForm.classList.remove('active');
                verifyForm.classList.add('active');

                showMessage('OTP sent successfully to your email.', 'success');
            } else {
                showMessage(data.message || 'Failed to send OTP.', 'error');
            }
        } catch (error) {
            showMessage('Network error. Please try again.', 'error');
        } finally {
            toggleLoading(requestBtn, false);
        }
    });

    verifyForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        const otp = document.getElementById('otp').value;

        toggleLoading(verifyBtn, true);

        try {
            const response = await fetch(API_VERIFY, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ email: currentEmail, otp }),
                credentials: 'omit'
            });

            const data = await response.json();

            if (response.ok) {
                showMessage('OTP Verified Successfully!', 'success');
                // Optional: redirect or change UI state for logged in
                setTimeout(() => {
                    verifyForm.innerHTML = '<div style="text-align:center; padding: 20px;"><h3>Authentication Complete</h3><p>Welcome, your identity is verified.</p></div>';
                }, 1500);
            } else {
                showMessage(data.message || 'Invalid OTP.', 'error');
            }
        } catch (error) {
            showMessage('Network error. Please try again.', 'error');
        } finally {
            toggleLoading(verifyBtn, false);
        }
    });

    backToRequest.addEventListener('click', (e) => {
        e.preventDefault();
        verifyForm.classList.remove('active');
        requestForm.classList.add('active');
        document.getElementById('otp').value = '';
    });
});
